# Lab 9 Notes — One Cart, Four Ways (`setState`, `Riverpod`, `Cubit`, `Bloc`)

---

## 1. Inline Questions (Parts 1–5)

### Part 1 — Setup & Shared Code

1. **Why is `CartLine` immutable with a `copyWith` instead of a mutable `qty` field? Which of the four styles would still "work" with mutation, and why is that a trap?**
   - **Why immutable:** Riverpod (`Notifier`), Cubit, and Bloc compare `previous == next` (or check identity) before notifying listeners or rebuilding selectors. If `qty` were mutated in place inside the same `CartLine` / `List<CartLine>`, the old and new state references would still compare equal, so updates would be silently dropped.
   - **Which style still "works":** `setState` still appears to work because calling `setState(() { ... })` unconditionally marks the `Element` dirty and schedules a rebuild regardless of object identity or equality.
   - **Why it is a trap:** (1) It breaks sharing pure model helpers across Riverpod, Cubit, and Bloc, (2) it breaks selective rebuild checks (`select` / `buildWhen`) and `Equatable` comparisons, and (3) mutating objects in place silently corrupts previous snapshots saved in undo `_history`.

2. **Why does `CartBody` take callbacks rather than importing a provider or a bloc directly?**
   - Keeping `CartBody` (`lib/widgets/cart_body.dart`) as a dumb presentation widget decoupled from any state-management library allows all four screens (`SetStateCartPage`, `RiverpodCartPage`, `CubitCartPage`, `BlocCartPage`) to reuse the exact same UI, keeps business/wiring concerns out of leaf widgets, and allows testing or previewing `CartBody` without wrapping it in a `ProviderScope` or `BlocProvider`.

---

### Part 2 — `setState`

1. **Why is storing `total` (or `itemCount`, `subtotal`, `discount`) as stored fields on `CartState` a bug waiting to happen (T3)?**
   - Stored derived values can easily drift out of sync with `lines` and `coupon` if any mutation (`add`, `changeQty`, `applyCoupon`, `undo`, `reset`) forgets to recompute them. Defining `itemCount`, `subtotal`, `discount`, `total`, and `canUndo` as pure getters guarantees a single source of truth.

2. **Why must you guard with `if (!mounted) return;` after `await` in `_checkout()`, and what happens without it (T4)?**
   - If the user navigates back while `CheckoutApi.submit` is still running (1500 ms), `_SetStateCartPageState` is disposed and `mounted` becomes `false`. Without `if (!mounted) return;`, calling `setState(...)` throws `FlutterError: setState() called after dispose()`, and accessing `BuildContext` throws an exception about using a deactivated widget's context.

3. **After T4, how would a second page (e.g., an order history page) read the cart? What would you have to change?**
   - It could not read `_state` directly because `_state` lives privately inside `_SetStateCartPageState` and is destroyed when the page is popped. You would have to lift the state above the `Navigator` (into a parent/root `StatefulWidget` or an `InheritedWidget` / `ChangeNotifier`) and pass state and callbacks down manually (prop drilling).

4. **After T5, where does `_history` live, and what happens to it on hot reload versus hot restart?**
   - `_history` is stored as a field on `_SetStateCartPageState` inside the widget tree's `State` object.
   - **Hot reload:** Preserves existing `State` instances, so `_history` and `_state` survive.
   - **Hot restart:** Restarts the Dart isolate from `main()`, destroying the widget tree and resetting `_history` to empty.

---

### Part 3 — Riverpod

1. **Does `state = state.copyWith(coupon: code)` notify if `code` is unchanged, before vs after overriding `==` / `hashCode` (`Equatable`) on `CartState` (T2)?**
   - **Without `Equatable` / `==`:** `copyWith` allocates a new `CartState` instance, so `previous == next` falls back to reference identity (`false`) and notifies listeners needlessly even when nothing changed.
   - **With `Equatable`:** `previous == next` is `true` when the fields match, so `NotifierProvider.updateShouldNotify` returns `false` and suppresses redundant notifications/rebuilds.

2. **Why is no widget `mounted` check needed in `CartNotifier.checkout()` (T4)?**
   - Because `cartProvider` is a non-`autoDispose` `NotifierProvider` owned by the root `ProviderScope`'s `ProviderContainer`. Popping `RiverpodCartPage` unmounts the widget, not the `CartNotifier`, so writing `state = ...` after `await` remains valid. *(Note: if the provider were `.autoDispose` or the container itself were disposed, Riverpod 3.x exposes `ref.mounted` to guard against writing after disposal.)*

3. **What happens to `_history` if you make `cartProvider` `autoDispose`, pop the page, and return (T5)?**
   - When `RiverpodCartPage` pops, `cartProvider` loses its last listener and is automatically disposed by Riverpod, discarding `CartNotifier` and `_history`. Re-opening the page builds a fresh `CartNotifier` with empty cart state and empty `_history`.

4. **Name the three places you used `ref.read` and the two places you used `ref.watch`, and justify each:**
   - **`ref.watch` (reactive subscriptions in build/providers):**
     1. `RiverpodCartPage.build`: watches `cartProvider` and `canUndoProvider` (whose own body uses `ref.watch(cartProvider.select((s) => s.history.isNotEmpty))`) so the page and AppBar Undo button rebuild whenever cart lines, coupon error, checkout status, or undo availability change.
     2. `_RiverpodSummaryCard.build`: watches `cartProvider.select((s) => (s.itemCount, s.subtotal, s.discount, s.total))` so only the summary card rebuilds when pricing/quantity numbers change.
   - **`ref.read` (one-off non-subscribing lookups):**
     1. `RiverpodCartPage.build`: `ref.read(cartProvider.notifier)` to obtain method handles (`add`, `changeQty`, `applyCoupon`, `checkout`, `undo`) for widget callbacks without subscribing to rebuilds.
     2. `CartNotifier.checkout()`: `ref.read(checkoutApiProvider)` inside an imperative async action to read the injected `CheckoutApi` dependency.
     3. `RiverpodCartPage.build` inside `ref.listen`: `ref.read(cartProvider).orderId` and `ref.read(cartProvider).checkoutError` inside the side-effect callback when `status` changes to `success` or `failure`.

5. **Why does the summary card in T3 rebuild less often than the `setState` version?**
   - In `setState`, any `setState()` call re-runs `SetStateCartPage.build`, passing props down and rebuilding `CartSummaryCard` even when only `couponError` or `CheckoutStatus` changed. In Riverpod, `_RiverpodSummaryCard` is `const` and uses `cartProvider.select((s) => (s.itemCount, s.subtotal, s.discount, s.total))`, so it ignores typing in the coupon field, invalid-coupon error changes, and `submitting`/`failure` status changes.

---

### Part 4 — Cubit

1. **What happens if you leave the page mid-checkout in Cubit, and why do we guard with `if (isClosed) return;` (T4)?**
   - `BlocProvider` scopes `CartCubit` to `CubitCartPage`'s subtree and calls `cubit.close()` when the page is popped. Calling `emit(...)` after `close()` throws `StateError: Cannot emit new states after calling close`. Checking `if (isClosed) return;` after `await` prevents that error.

2. **Why isn't `bool get canUndo` on `CartCubit` observable by `BlocBuilder`, and how do we fix it (T5)?**
   - `BlocBuilder` only reacts to `CartState` emissions on the Cubit's stream—not to private fields or computed getters on the Cubit class itself. Storing `history` inside `CartState` (with `canUndo => history.isNotEmpty`) makes undo state part of every emitted `CartState`, so `BlocSelector<CartCubit, CartState, bool>` updates the Undo button cleanly.

3. **What would break if you put `BlocProvider` inside `CartBody`?**
   - First, `CartBody` would import `flutter_bloc`, breaking style independence across all four implementations. Second, `CubitCartPage`'s `AppBar` Undo button, `BlocListener`, and `BlocBuilder` sit *above* `CartBody`, so `context.read<CartCubit>()` and `BlocBuilder<CartCubit, CartState>` would throw `ProviderNotFoundException` because `BlocProvider` only provides to descendants below it in the tree.

4. **Riverpod equivalents:**
   - `BlocProvider` → `ProviderScope` + `NotifierProvider` (or `ProviderScope(overrides: ...)` for subtree scoping)
   - `BlocBuilder` → `Consumer` / `ConsumerWidget` + `ref.watch(...)`
   - `BlocListener` → `ref.listen(...)`
   - `context.read` → `ref.read(...)`
   - `buildWhen` → `ref.watch(provider.select((s) => ...))`

---

### Part 5 — Bloc

1. **What extra information does `BlocObserver.onTransition` provide compared to Cubit's `onChange` (T2)?**
   - `onChange` logs only `(currentState, nextState)`. `onTransition` logs `(currentState, event, nextState)`, including the exact `CartEvent` instance and payload (e.g., `CartProductAdded`, `CartCouponApplied`, `CartCheckoutRequested`) that triggered the state change.

2. **What happens with `transformer: droppable()` when tapping Checkout three times quickly, and what would happen in Cubit (T4)?**
   - With `droppable()` on `on<CartCheckoutRequested>`, the first event executes `_onCheckout` and emits `submitting`; the 2nd and 3rd events arriving while `api.submit` is still in flight are dropped immediately, so only one API call runs. In Cubit (without an explicit `if (state.status == CheckoutStatus.submitting) return;` guard), three rapid taps invoke `checkout()` three times concurrently.

3. **Should every event push to undo history? Which events are undoable (T5)?**
   - No. Only cart-content and coupon mutations (`CartProductAdded`, `CartQtyChanged`, `CartCouponApplied`) push a snapshot onto `history`. `CartCheckoutRequested` (async status transition) and `CartUndone` (history pop) do not push to `history`, expressed cleanly via an exhaustive `switch` on the `sealed class CartEvent`.

4. **When is the event layer worth its boilerplate? One cart feature where Bloc is clearly better than Cubit, and one where it is pure overhead:**
   - **Worth it when:** You need declarative event concurrency (`droppable`, `restartable`, `debounce`, `sequential`), full audit/analytics trails (`onTransition` capturing user intent as data), or decoupled event producers.
   - **Clearly better in this cart:** `CartCheckoutRequested` with `transformer: droppable()` (one line prevents duplicate submissions declaratively).
   - **Pure overhead in this cart:** Simple synchronous mutations like `CartProductAdded` and `CartQtyChanged`, where an event class + `on<E>` handler merely delegates to `state.withProduct(p)` / `state.withQtyChanged(id, delta)` compared to calling `cubit.add(p)` directly.

5. **Which of the four styles let you implement T4's "drop duplicate taps" declaratively, and how would you do it in the others?**
   - **Declaratively:** **Bloc** via `on<CartCheckoutRequested>(_onCheckout, transformer: droppable())`.
   - **In `setState`, `Riverpod`, and `Cubit`:** Imperatively guard `if (state.status == CheckoutStatus.submitting) return;` at the start of `checkout()` (or disable the Checkout button in the UI while `status == CheckoutStatus.submitting`).

---

## 2. Checkpoint Questions (Page 9)

1. **Where the state lives and when it dies (one line each):**
   - **`setState`:** Lives inside `_SetStateCartPageState` on the widget's `Element` in the widget tree; dies when `SetStateCartPage` is popped/unmounted.
   - **`Riverpod`:** Lives inside the root `ProviderScope`'s `ProviderContainer` outside the widget tree; survives page pops and dies only when the container is disposed (unless `.autoDispose` is used).
   - **`Cubit`:** Lives inside the `CartCubit` instance owned by `BlocProvider` in `CubitCartPage`'s subtree; dies (`close()`) when `CubitCartPage` is popped.
   - **`Bloc`:** Lives inside the `CartBloc` instance owned by `BlocProvider` in `BlocCartPage`'s subtree; dies (`close()`) when `BlocCartPage` is popped.

2. **Single public mutation API per style:**
   - **Riverpod (`Notifier`):** Assigning `state = newState` inside the `Notifier` (UI calls notifier methods).
   - **Cubit:** Calling `emit(newState)` inside the `Cubit` (UI calls cubit methods).
   - **Bloc:** Calling `bloc.add(event)` from outside (`Bloc` handlers emit via `Emitter<CartState>`).
   - **Style with none:** `setState` has no separate state holder or single public mutation API—any method on the `State` class mutates fields directly inside `setState(() { ... })`.

3. **Subscription primitive mapping & where `setState` fits:**
   - `ref.watch` ↔ `BlocBuilder` (and `ref.watch(p.select(...))` ↔ `BlocSelector` / `buildWhen`) — subscribes UI and rebuilds on state changes.
   - `ref.read` ↔ `context.read` — one-off lookup without subscribing, used inside callbacks and imperative actions.
   - `ref.listen` ↔ `BlocListener` — runs side effects (`SnackBar`, `MaterialBanner`, navigation) on state transitions without rebuilding widgets.
   - Where `setState` fits: It has no granular subscription or listener API; `setState(() { ... })` dirties the whole `State` element so `build()` re-runs top-down and passes values/callbacks through constructor props, while async side effects run directly after `await` guarded by `mounted`.

4. **Why Riverpod, Cubit, and Bloc skip notifying when `newState == oldState`, and two requirements on `CartState`:**
   - **Why:** Skipping equal states prevents wasted widget rebuilds, duplicate side-effect listeners, and noisy stream emissions when a mutation yields no logical state change (e.g., applying `'SAVE10'` twice).
   - **Two requirements on `CartState`:** (1) **Immutability** (`final` fields + `copyWith` producing new objects instead of mutating in place), and (2) **Value equality** (`extends Equatable` with UI-relevant fields in `props`, or custom `==` and `hashCode`, omitting `history` or handling it so duplicate mutations compare equal).

5. **Post-`await` guards (`mounted`, nothing, `isClosed`, `emit.isDone`) and why they differ:**
   - **`setState` (`if (!mounted) return;`):** State is tied to a `StatefulWidget`'s `Element`/`BuildContext`; leaving the page unmounts it, making `setState` or `context` access invalid.
   - **`Riverpod` (nothing for non-`autoDispose` `Notifier`):** The `Notifier` lives in the root `ProviderContainer` and outlives page pops, so assigning `state` stays valid. *(With `.autoDispose`, check `ref.mounted`.)*
   - **`Cubit` (`if (isClosed) return;`):** `BlocProvider` closes `CartCubit` when the page pops, and `emit` throws `StateError` if called after `close()`.
   - **`Bloc` (`if (emit.isDone) return;`):** Each `on<Event>` handler receives a scoped `Emitter`; `emit.isDone` becomes `true` if the Bloc is closed *or* if an event concurrency transformer cancels/completes that handler early.

---

## 3. Grading Comparison Table

Line counts measured directly from the committed implementation files (`lib/setstate/`, `lib/riverpod/`, `lib/cubit/`, `lib/bloc/`, and `test/`):

| Style | LOC for T1–T5 (`lib/<style>/`) | Lines of Test Code (`test/`) | Files (`lib` + `test`) | One Strength | One Weakness |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **`setState`** | 111 total (98 non-empty) | 23 total (19 non-empty) | 1 + 1 = 2 | Zero external dependencies and minimal boilerplate for single-screen local state. | State dies on page pop, cannot be shared across sibling routes without lifting/prop drilling, and rebuilds the entire widget subtree on every mutation. |
| **`Riverpod`** | 158 total (139 non-empty) | 46 total (37 non-empty) | 2 + 1 = 3 | Compile-safe, widget-tree-independent dependency injection (`checkoutApiProvider`), granular `.select()` rebuilds, and pure Dart unit testing with `ProviderContainer`. | Requires a `ProviderScope` root and `ConsumerWidget`/`WidgetRef`, and side-effect/concurrency policies (`droppable`) must be coded imperatively inside methods. |
| **`Cubit`** | 162 total (146 non-empty) | 56 total (51 non-empty) | 2 + 1 = 3 | Clean method-call API with sequential state-stream testing (`blocTest`), easy subtree scoping via `BlocProvider`, and automatic duplicate-state deduplication. | No event objects (`onTransition` cannot log *which* action fired, and concurrency transformers like `droppable()` are unavailable); requires `isClosed` guards after `await`. |
| **`Bloc`** | 206 total (184 non-empty) | 80 total (74 non-empty) | 3 + 1 = 4 | Explicit sealed events enable declarative concurrency (`transformer: droppable()`), exhaustive `switch` logic, and rich `onTransition` audit logs. | Highest boilerplate (separate event classes, `on<E>` handlers, and `.add(Event)` dispatch calls even for trivial synchronous mutations). |

