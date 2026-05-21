//
//  ToDoWidgetBundle.swift
//  ToDoWidget
//
//  Created by Moinuddin Ahmad on 5/17/26.
//

import WidgetKit
import SwiftUI

@main
struct ToDoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToDoWidget()
        ToDoWidgetLiveActivity()
    }
}
