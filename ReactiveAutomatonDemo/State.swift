//
//  State.swift
//  ReactiveAutomatonDemo
//
//  Created by 吴哲 on 2021/12/2.
//  Copyright © 2021 Yasuhiro Inami. All rights reserved.
//

enum State: String, CustomStringConvertible
{
    case loggedOut
    case loggingIn
    case loggedIn
    case loggingOut

    var description: String { return "state:" + self.rawValue }
}
