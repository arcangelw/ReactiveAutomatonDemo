//
//  Input.swift
//  ReactiveAutomatonDemo
//
//  Created by 吴哲 on 2021/12/2.
//  Copyright © 2021 Yasuhiro Inami. All rights reserved.
//

import Foundation

/// Input
enum Input: String, CustomStringConvertible
{
    case login
    case loginOK
    case logout
    case forceLogout
    case logoutOK

    var description: String { return "input:" + self.rawValue }
}
