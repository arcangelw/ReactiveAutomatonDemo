import ReactiveSwift

/// 自动状态机，接受输入并将当前状态转换为下一个状态和副作用信号
public final class Automaton<Input, State> {
    /// 基本状态转换（没有副作用） 将输入&当前状态转化为下一个状态
    public typealias Mapping = (Input, State) -> State?

    /// 带副作用的状态转换 将输入&当前状态转化为下一个状态&副作用
    public typealias EffectMapping<Queue, EffectID> = (Input, State) -> (State, Effect<Input, Queue, EffectID>)?
        where Queue: EffectQueueProtocol, EffectID: Equatable

    /// 输入状态转换返回结果信号
    public let replies: Signal<Reply<Input, State>, Never>

    /// 当前状态
    public let state: Property<State>

    private let _repliesObserver: Signal<Reply<Input, State>, Never>.Observer

    private let _disposable: Disposable

    /// 通过没有副作用的状态转换映射创建一个自动机
    ///
    /// - Parameters:
    ///   - state: 初始化状态
    ///   - input: 输入数据信号
    ///   - mapping: 没有副作用的状态转换映射
    public convenience init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping Mapping
    ) {
        self.init(
            state: initialState,
            inputs: inputSignal,
            mapping: { mapping($0, $1).map { ($0, Effect<Input, Never, Never>.none) } }
        )
    }

    /// 通过带有副作用的状态转换映射创建一个自动机.
    ///
    /// - Parameters:
    ///   - state: 初始化状态
    ///   - effect: 初始化状态时的一个副作用，默认给一个空信号副作用
    ///   - input: 输入数据信号
    ///   - mapping: 带有副作用的状态转换映射
    public convenience init<Queue, EffectID>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .none,
        inputs inputSignal: Signal<Input, Never>,
        mapping: @escaping EffectMapping<Queue, EffectID>
    ) where Queue: EffectQueueProtocol {
        self.init(
            state: initialState,
            inputs: inputSignal,
            makeSignals: { from -> MakeSignals in
                let mapped: Signal<(Input, State, (State, Effect<Input, Queue, EffectID>)?), Never> = from
                    .map { input, fromState in
                        (input, fromState, mapping(input, fromState))
                    }

                let replies = mapped
                    .map { input, fromState, mapped -> Reply<Input, State> in
                        if let (toState, _) = mapped {
                            return .success((input, fromState, toState))
                        } else {
                            return .failure((input, fromState))
                        }
                    }

                let effects = mapped
                    .compactMap { $0.2?.1 }
                    .producer
                    .prefix(value: initialEffect)
//                    .compactMap { _, _, mapped -> Effect<Input, Queue, EffectID> in
//                        guard case let .some((_, effect)) = mapped else { return .none }
//                        return effect
//                    }
//                    .producer
//                    .prefix(value: initialEffect)

                let producers = effects.compactMap { $0.producer }
                let cancels = effects.compactMap { $0.cancel }
                let effectInputs = SignalProducer.merge(
                    EffectQueue<Queue>.allCases.map { queue in
                        producers
                            .filter { $0.queue == queue }
                            .flatMap(queue.flattenStrategy) { producer -> SignalProducer<Input, Never> in
                                guard let producerID = producer.identifier else {
                                    return producer.producer
                                }

                                let until = cancels.filter { $0(producerID) }.map { _ in }
                                return producer.producer.take(until: until)
                            }
                    }
                )

                return (replies, effectInputs)
            }
        )
    }

    /// 内部初始化函数
    /// - Parameters:
    ///   - initialState: 初始化状态
    ///   - inputSignal: 输入信号
    ///   - makeSignals: 状态与副作用信号转换
    internal init(
        state initialState: State,
        inputs inputSignal: Signal<Input, Never>,
        makeSignals: (Signal<(Input, State), Never>) -> MakeSignals
    ) {
        /// 可变属性状态
        let stateProperty = MutableProperty(initialState)
        /// 不可变属性状态 对外暴露为当前自动机状态
        state = Property(capturing: stateProperty)

        /// 创建一个转换值信号
        (self.replies, _repliesObserver) = Signal<Reply<Input, State>, Never>.pipe()

        /// 创建一个副作用对输入数据的转换信号
        let effectInputs = Signal<Input, Never>.pipe()
        /// 合并输入信号与副作用转换后的输出信号
        let mergedInputs = Signal.merge(inputSignal, effectInputs.output)

        /// 合并输入数据与当前状态
        let mapped = mergedInputs
            .withLatest(from: stateProperty.producer)

        /// 转换为状态反馈与副作用信号
        let (replies, effects) = makeSignals(mapped)

        let disp = CompositeDisposable()

        /// 订阅绑定状态反馈值的转换状态
        disp += stateProperty <~ replies.compactMap { $0.toState }

        /// 输入状态转换返回结果实时订阅更新自动机器返回值
        disp += replies.observeValues(_repliesObserver.send(value:))

        /// 副作用执行订阅
        let effectDisposable = effects.start(effectInputs.input)

        disp += effectDisposable

        /// 输入信号结束时候 结束状态机所有信号
        disp += inputSignal
            .observeCompleted { [_repliesObserver] in // swiftlint:disable:this identifier_name
                effectDisposable.dispose()
                _repliesObserver.sendCompleted()
                effectInputs.input.sendCompleted()
            }

        /// 输入信号中断时候 中断状态机所有信号
        disp += inputSignal
            .observeInterrupted { [_repliesObserver] in // swiftlint:disable:this identifier_name
                effectDisposable.dispose()
                _repliesObserver.sendInterrupted()
                effectInputs.input.sendInterrupted()
            }

        _disposable = disp
    }

    deinit {
        self._repliesObserver.sendCompleted()
        self._disposable.dispose()
    }
}

extension Automaton {
    /// 转换为状态反馈值信号与副作用信号
    typealias MakeSignals = (
        replies: Signal<Reply<Input, State>, Never>,
        effects: SignalProducer<Input, Never>
    )
}
