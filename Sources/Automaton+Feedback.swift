import ReactiveSwift

extension Automaton {
    ///  Feedback执行副作用
    ///  将状态机对应状态变化的返回值转换为下一个输入数据
    ///
    /// - Parameters:
    ///   - state: 初始化状态
    ///   - input: 输入数据信号
    ///   - mapping: 没有副作用的状态转换映射
    ///   - feedback: 状态机对应状态变化的返回值转换为下一个输入数据
    public convenience init(
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

                /// 副作用输入信号转换
                let effects = feedback.transform(replies.compactMap { $0.success }).producer

                return (replies, effects)
            }
        )
    }
}
