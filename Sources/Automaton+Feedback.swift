import ReactiveSwift

public extension Automaton {
    /// Initializer using `feedback` for injecting side-effects.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: `Signal<Input, Never>` that automaton receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    ///   - feedback: `Signal` transformer that performs side-effect and emits next input.
    convenience init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping Mapping,
        feedback: Feedback<Reply<Input, State>.Success, Input>
    ) {
        self.init(
            state: initialState,
            inputs: inputSignal,
            makeSignals: { from -> MakeSignals in
                let mapped: Signal<(Input, State, State?), Never> = from
                    .map { input, fromState in
                        (input, fromState, mapping(input, fromState))
                    }
                let replies = mapped
                    .map { input, fromState, mapped -> Reply<Input, State> in
                        if let toState = mapped {
                            return .success((input, fromState, toState))
                        } else {
                            return .failure((input, fromState))
                        }
                    }

                let effects = feedback.transform(replies.compactMap { $0.success }).producer

                return (replies, effects)
            }
        )
    }
}
