import SwiftUI

struct BasicSettingsView: View {
    @Bindable var vm: ConfigViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox(label: Label("月薪设置", systemImage: "yensign.circle")) {
                    HStack {
                        Text("月薪")
                        Spacer()
                        TextField("月薪", value: $vm.monthlySalary, format: .number)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)
                        Text("元/月")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                GroupBox(label: Label("发薪日设置", systemImage: "calendar.badge.clock")) {
                    HStack {
                        Text("每月发薪日")
                        Spacer()
                        Stepper("", value: $vm.payday, in: 1...31)
                            .labelsHidden()
                        TextField("", value: $vm.payday, format: .number)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                        Text("号")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
    }
}
