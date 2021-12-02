//
//  ViewController.swift
//  ReactiveAutomatonDemo
//
//  Created by 吴哲 on 2021/12/2.
//  Copyright © 2021 Yasuhiro Inami. All rights reserved.
//

import UIKit
import Pulsator
import ReactiveCocoa
import ReactiveSwift
import ReactiveAutomaton

final class AutomatonViewController: UIViewController {

    enum Latest: EffectQueueProtocol {
        case latest
        static var allCases: [Latest] {
            return [.latest]
        }

        var flattenStrategy: FlattenStrategy {
            return .latest
        }
    }

    typealias Queue = Latest
    typealias EffectID = Never
    typealias Automaton = ReactiveAutomaton.Automaton<Input, State>
    typealias EffectMapping = Automaton.EffectMapping<Queue, EffectID>

    @IBOutlet weak var diagramView: UIImageView!
    @IBOutlet weak var label: UILabel!

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var forceLogoutButton: UIButton!
    
    private var pulsator: Pulsator!

    private var automaton: Automaton!

    override func viewDidLoad()
    {
        super.viewDidLoad()

        let (textSignal, textObserver) = Signal<String?, Never>.pipe()

        func countUpProducer(status: String, count: Int = 4, interval: DispatchTimeInterval = .seconds(1), nextInput: Input) -> SignalProducer<Input, Never>
        {
            
            return SignalProducer.interval(interval, on: QueueScheduler.main)
                .take(first: count)
                .scan(0) { x, _ in x + 1 }
                .prefix(value: 0)
                .map {
                    switch $0 {
                        case 0:     return "\(status)..."
                        case count: return "\(status) Done!"
                        default:    return "\(status)... (\($0))"
                    }
                }.on(value: { textObserver.send(value: $0)})
                .then(.init(value: nextInput))
        }

        let loginOKProducer = countUpProducer(status: "Login", nextInput: .loginOK)
        let logoutOKProducer = countUpProducer(status: "Logout", nextInput: .logoutOK)
        let forceLogoutOKProducer = countUpProducer(status: "ForceLogout", nextInput: .logoutOK)
        let canForceLogout: (State) -> Bool = [.loggingIn, .loggedIn].contains

        /// Transition mapping.
        let mappings: [EffectMapping] = [

//          /*  Input   |   fromState => toState     |      Effect       */
//          /* ----------------------------------------------------------*/
            .login    | .loggedOut  => .loggingIn  | (loginOKProducer, Queue.latest),
            .loginOK  | .loggingIn  => .loggedIn   | (.empty, Queue.latest),
            .logout   | .loggedIn   => .loggingOut | (logoutOKProducer, Queue.latest),
            .logoutOK | .loggingOut => .loggedOut  | (.empty, Queue.latest),
            .forceLogout | canForceLogout => .loggingOut | (forceLogoutOKProducer, Queue.latest)
        ]

        let (inputSignal, inputObserver) = Signal<Input, Never>.pipe()

        automaton = Automaton(state: .loggedOut, inputs: inputSignal, mapping: reduce(mappings))

        automaton.replies
            .take(duringLifetimeOf: self)
            .observeValues({ reply in
                print("received reply = \(reply)")
            })

        automaton.state.producer
            .take(duringLifetimeOf: self)
            .startWithValues({ state in
                print("current state = \(state)")
            })

        do {
            self.loginButton.reactive.controlEvents(.touchUpInside)
                .take(duringLifetimeOf: self)
                .observeValues { _ in
                    inputObserver.send(value: .login)
                }

            self.logoutButton.reactive.controlEvents(.touchUpInside)
                .take(duringLifetimeOf: self)
                .observeValues { _ in
                    inputObserver.send(value: .logout)
                }

            self.forceLogoutButton.reactive.controlEvents(.touchUpInside)
                .take(duringLifetimeOf: self)
                .observeValues { _ in
                    inputObserver.send(value: .forceLogout)
                }
        }

        do {
            self.label.reactive.text <~ textSignal.take(duringLifetimeOf: self)
        }

        do {
            let pulsator = _createPulsator()
            self.pulsator = pulsator

            self.diagramView?.layer.addSublayer(pulsator)

            pulsator.reactive[\.backgroundColor] <~ automaton.state.producer
                .take(duringLifetimeOf: self)
                .map(_pulsatorColor)
                .map { $0.cgColor }

            pulsator.reactive[\.position] <~ automaton.state.producer
                .take(duringLifetimeOf: self)
                .map(_pulsatorPosition)

            pulsator.reactive[\.backgroundColor] <~ automaton.replies
                .take(duringLifetimeOf: self)
                .filter { $0.toState != nil && $0.input == .forceLogout }
                .map { _ in UIColor.red.cgColor }
        }

    }

}

// MARK: Pulsator

private func _createPulsator() -> Pulsator
{
    let pulsator = Pulsator()
    pulsator.numPulse = 5
    pulsator.radius = 100
    pulsator.animationDuration = 7
    pulsator.backgroundColor = UIColor(red: 0, green: 0.455, blue: 0.756, alpha: 1).cgColor

    pulsator.start()

    return pulsator
}

private func _pulsatorPosition(state: State) -> CGPoint
{
    switch state {
        case .loggedOut:    return CGPoint(x: 40, y: 100)
        case .loggingIn:    return CGPoint(x: 190, y: 20)
        case .loggedIn:     return CGPoint(x: 330, y: 100)
        case .loggingOut:   return CGPoint(x: 190, y: 180)
    }
}

private func _pulsatorColor(state: State) -> UIColor
{
    switch state {
        case .loggedOut:
            return UIColor(red: 0, green: 0.455, blue: 0.756, alpha: 1)     // blue
        case .loggingIn, .loggingOut:
            return UIColor(red: 0.97, green: 0.82, blue: 0.30, alpha: 1)    // yellow
        case .loggedIn:
            return UIColor(red: 0.50, green: 0.85, blue: 0.46, alpha: 1)    // green
    }
}


