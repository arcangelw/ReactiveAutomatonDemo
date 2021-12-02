import ReactiveSwift

/// - SeeAlso: https://github.com/Babylonpartners/ReactiveFeedback
/// - SeeAlso: https://github.com/NoTests/RxFeedback
public struct Feedback<Input, Output> {
    internal let transform: (Signal<Input, Never>) -> Signal<Output, Never>

    public init(transform: @escaping (Signal<Input, Never>) -> Signal<Output, Never>) {
        self.transform = transform
    }

    public init(produce: @escaping (Input) -> SignalProducer<Output, Never>) {
        self.init(transform: { $0 }, produce: produce)
    }

    public init<U>(
        transform: @escaping (Signal<Input, Never>) -> Signal<U, Never>,
        produce: @escaping (U) -> SignalProducer<Output, Never>,
        strategy: FlattenStrategy = .latest
    ) {
        self.transform = {
            transform($0)
                .flatMap(strategy) { produce($0) }
        }
    }

    public init<U>(
        tryGet: @escaping (Input) -> U?,
        produce: @escaping (U) -> SignalProducer<Output, Never>
    ) {
        self.init(
            transform: { $0.map(tryGet) },
            produce: { $0.map(produce) ?? .empty }
        )
    }

    public init(
        filter: @escaping (Input) -> Bool,
        produce: @escaping (Input) -> SignalProducer<Output, Never>
    ) {
        self.init(
            transform: { $0.filter(filter) },
            produce: produce
        )
    }
}

// MARK: - Functions

/// 将多个状态反馈折叠
public func reduce<Input, Output>(_ feedbacks: [Feedback<Input, Output>]) -> Feedback<Input, Output> {
    return Feedback<Input, Output> { signal in
        Signal.merge(feedbacks.map { $0.transform(signal) })
    }
}
