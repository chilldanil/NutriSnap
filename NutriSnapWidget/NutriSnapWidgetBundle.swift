import WidgetKit
import SwiftUI

@main
struct NutriSnapWidgetBundle: WidgetBundle {
    var body: some Widget {
        NutriSnapWidget()
        NutriSnapLiveActivity()
    }
}
