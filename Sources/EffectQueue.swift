import ReactiveSwift

// MARK: - EffectQueueProtocol

/// 副作用实现队列协议
public protocol EffectQueueProtocol: Equatable, CaseIterable {
    var flattenStrategy: FlattenStrategy { get }
}

/// 没有副作用实现
extension Never: EffectQueueProtocol {
    public static var allCases: [Never] {
        return [Never]()
    }

    public var flattenStrategy: FlattenStrategy {
        return .merge
    }
}

// MARK: - EffectQueue

/// 提供一个默认副作用执行队列
internal enum EffectQueue<Queue>: EffectQueueProtocol
    where Queue: EffectQueueProtocol {
    case `default`
    case custom(Queue)

    public static var allCases: [EffectQueue] {
        return [.default] + Queue.allCases.map(EffectQueue.custom)
    }

    public var flattenStrategy: FlattenStrategy {
        switch self {
        case .default:
            return .merge
        case let .custom(custom):
            return custom.flattenStrategy
        }
    }
}
