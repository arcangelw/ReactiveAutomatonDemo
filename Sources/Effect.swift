import Foundation
import ReactiveSwift

/// 状态变化的副作用
public struct Effect<Input, Queue, ID>
    where Queue: EffectQueueProtocol, ID: Equatable {
    internal let kind: Kind

    internal init(kind: Kind) {
        self.kind = kind
    }

    /// 执行副作用的冷信号， 会在队列中按照指定策略执行
    /// - Parameters:
    ///   - producer: 执行副作用并发送下一个`Input`的冷信号
    ///   - queue: 配置执行队列信号处理策略
    ///   - identifier: 执行标识，可以用来取消副作用信号
    public init(
        _ producer: SignalProducer<Input, Never>,
        queue: Queue? = nil,
        identifier: ID? = nil
    ) {
        self.init(kind: .producer(
            Producer(
                producer: producer,
                queue: queue.map(EffectQueue.custom) ?? .default,
                identifier: identifier
            )
        ))
    }

    /// 通过判断标示 取消对应的副作用信号
    public static func cancel(
        _ identifiers: @escaping (ID) -> Bool
    ) -> Effect<Input, Queue, ID> {
        return Effect(kind: .cancel(identifiers))
    }

    /// 通过指定标示 取消副作用信号
    public static func cancel(
        _ identifier: ID
    ) -> Effect<Input, Queue, ID> {
        return Effect(kind: .cancel { $0 == identifier })
    }

    /// 一个空信号副作用
    public static var none: Effect<Input, Queue, ID> {
        return Effect(.empty)
    }

    // MARK: - Functor

    /// 冷信号`Input`转换
    public func mapInput<Input2>(
        _ transform: @escaping (Input) -> Input2
    ) -> Effect<Input2, Queue, ID> {
        switch kind {
        case let .producer(producer):
            return .init(kind: .producer(Effect<Input2, Queue, ID>.Producer(
                producer: producer.producer.map(transform),
                queue: producer.queue,
                identifier: producer.identifier
            )))
        case let .cancel(predicate):
            return .cancel(predicate)
        }
    }
}

extension Effect: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self = .none
    }
}

extension Effect {
    var producer: Producer? {
        guard case let .producer(value) = kind else { return nil }
        return value
    }

    var cancel: ((ID) -> Bool)? {
        guard case let .cancel(value) = kind else { return nil }
        return value
    }
}

// MARK: - Inner Types

extension Effect {
    enum Kind {
        case producer(Producer)
        case cancel((ID) -> Bool)
    }

    struct Producer {
        /// 运行副作用并发送下一个`Input`的冷信号
        internal let producer: SignalProducer<Input, Never>

        /// 与`producer`关联以执行各种策略队列。
        internal let queue: EffectQueue<Queue>

        /// 取消`producer`运行的标示id
        internal let identifier: ID?
    }
}
