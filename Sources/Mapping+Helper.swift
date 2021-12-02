import ReactiveSwift

/// 状态转换
public struct Transition<State> {
    public let fromState: (State) -> Bool
    public let toState: State
}

// MARK: - 自定义操作符

// MARK: `=>` (状态转换操作符 优先级高于`|`快速构造自动机)

precedencegroup TransitionPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}

infix operator =>: TransitionPrecedence // higher than `|`

/// create Transition
/// - Returns: Transition
public func => <State>(left: @escaping (State) -> Bool, right: State) -> Transition<State> {
    return Transition(fromState: left, toState: right)
}

/// create Transition
/// - Returns: Transition
public func => <State: Equatable>(left: State, right: State) -> Transition<State> {
    return { $0 == left } => right
}

// MARK: `|` (操作符 快速构造一个不带副作用的自动机)

// infix operator | : AdditionPrecedence   // Comment-Out: already built-in

///  create Mapping
/// - Returns: Mapping
public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: Transition<State>
) -> Automaton<Input, State>.Mapping {
    return { input, fromState in
        if inputFunc(input), transition.fromState(fromState) {
            return transition.toState
        } else {
            return nil
        }
    }
}

///  create Mapping
/// - Returns: Mapping
public func | <Input: Equatable, State>(
    input: Input,
    transition: Transition<State>
) -> Automaton<Input, State>.Mapping {
    return { $0 == input } | transition
}

///  create Mapping
/// - Returns: Mapping
public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: @escaping (State) -> State
) -> Automaton<Input, State>.Mapping {
    return { input, fromState in
        if inputFunc(input) {
            return transition(fromState)
        } else {
            return nil
        }
    }
}

///  create Mapping
/// - Returns: Mapping
public func | <Input: Equatable, State>(
    input: Input,
    transition: @escaping (State) -> State
) -> Automaton<Input, State>.Mapping {
    return { $0 == input } | transition
}

// MARK: `|` (操作符 快速构造一个带副作用的自动机)

///  create EffectMapping
/// - Returns: EffectMapping
public func | <Input, State, Queue, EffectID>(
    mapping: @escaping Automaton<Input, State>.Mapping,
    effect: SignalProducer<Input, Never>
) -> Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return mapping | Effect(effect)
}

///  create EffectMapping
/// - Returns: EffectMapping
public func | <Input, State, Queue, EffectID>(
    mapping: @escaping Automaton<Input, State>.Mapping,
    effect: (producer: SignalProducer<Input, Never>, queue: Queue)
) -> Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return mapping | Effect(effect.producer, queue: effect.queue)
}

/// EffectTuple
public typealias EffectTuple<Input, Queue, EffectID> = (producer: SignalProducer<Input, Never>, queue: Queue, identifier: EffectID)

///  create EffectMapping
/// - Returns: EffectMapping
public func | <Input, State, Queue, EffectID>(
    mapping: @escaping Automaton<Input, State>.Mapping,
    effect: EffectTuple<Input, Queue, EffectID>
) -> Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return mapping | Effect(effect.producer, queue: effect.queue, identifier: effect.identifier)
}

///  create EffectMapping
/// - Returns: EffectMapping
public func | <Input, State, Queue, EffectID>(
    mapping: @escaping Automaton<Input, State>.Mapping,
    effect: Effect<Input, Queue, EffectID>
) -> Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return { input, fromState in
        if let toState = mapping(input, fromState) {
            return (toState, effect)
        } else {
            return nil
        }
    }
}

// MARK: - Functions

/// 任意输入值 状态转换
/// - `let mapping = .input0 | any => .state1`
/// - `let mapping = any | .state1 => .state2`
public func any<T>(_: T) -> Bool {
    return true
}

/// 将多个状态转换折叠 最前有的转换优先级优先
public func reduce<Input, State, Mappings: Sequence>(_ mappings: Mappings)
    -> Automaton<Input, State>.Mapping
    where Mappings.Iterator.Element == Automaton<Input, State>.Mapping {
    return { input, fromState in
        for mapping in mappings {
            if let toState = mapping(input, fromState) {
                return toState
            }
        }
        return nil
    }
}

/// 将多个状态转换折叠 最前有的转换优先级优先
public func reduce<Input, State, Mappings: Sequence, Queue, EffectID>(_ mappings: Mappings)
    -> Automaton<Input, State>.EffectMapping<Queue, EffectID>
    where Mappings.Iterator.Element == Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return { input, fromState in
        for mapping in mappings {
            if let tuple = mapping(input, fromState) {
                return tuple
            }
        }
        return nil
    }
}

// MARK: - Mapping conversion

/// 转换添加一个空信号的副作用
public func toEffectMapping<Input, State, Queue, EffectID>(_ mapping: @escaping Automaton<Input, State>.Mapping)
    -> Automaton<Input, State>.EffectMapping<Queue, EffectID> {
    return { input, state in
        mapping(input, state).map { ($0, nil) }
    }
}

/// 舍弃副作用
public func toMapping<Input, State, Queue, EffectID>(
    _ effectMapping: @escaping Automaton<Input, State>.EffectMapping<Queue, EffectID>
) -> Automaton<Input, State>.Mapping {
    return { input, state in
        effectMapping(input, state)?.0
    }
}
