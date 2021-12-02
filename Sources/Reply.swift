/// 自动状态机对应状态变化的返回值
/// 包含成功 失败两种返回值
public enum Reply<Input, State> {
    /// 状态转换成功`(input, fromState, toState)`.
    case success(Success)

    /// 状态转换失败`(input, fromState)`.
    case failure(Failure)

    public var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }

    public var failure: Failure? {
        guard case let .failure(value) = self else { return nil }
        return value
    }

    public var input: Input {
        switch self {
        case let .success((input, _, _)): return input
        case let .failure((input, _)): return input
        }
    }

    public var fromState: State {
        switch self {
        case let .success((_, fromState, _)): return fromState
        case let .failure((_, fromState)): return fromState
        }
    }

    public var toState: State? {
        switch self {
        case let .success((_, _, toState)): return toState
        case .failure: return nil
        }
    }
}

extension Reply {
    /// 状态转换成功值 `(input, fromState, toState)`.
    public typealias Success = (input: Input, fromState: State, toState: State)

    /// 状态转换失败值 `(input, fromState)`.
    public typealias Failure = (input: Input, fromState: State)
}
