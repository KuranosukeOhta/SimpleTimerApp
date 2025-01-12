//
//  ContentView.swift
//  SinpleTimerApp Watch App
//
//  Created by Kuranosuke Ohta on 2025/01/12.
//

import SwiftUI
import WatchKit

struct TimePickerView: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var isMinutesFocused: Bool
    @Binding var isSecondsFocused: Bool
    @Binding var isEditing: Bool  // 編集中かどうかを管理
    
    var body: some View {
        HStack {
            VStack {
                Picker("", selection: $minutes) {
                    ForEach(0..<60) { minute in
                        Text("\(minute)")
                            .tag(minute)
                            .foregroundColor(isEditing && minutes == minute ? .green : .white)
                            .font(minutes == minute ? .title : .body)
                            .animation(.easeInOut(duration: 0.1), value: minutes)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 80)
                .opacity(isMinutesFocused ? 1.0 : 0.7)
                .onTapGesture {
                    isMinutesFocused = true
                    isSecondsFocused = false
                    isEditing = true
                }
                
                Text("分")
                    .font(.caption)
                    .padding(.top, -5)
            }

            VStack {
                Picker("", selection: $seconds) {
                    ForEach(0..<60) { second in
                        Text("\(second)")
                            .tag(second)
                            .foregroundColor(isEditing && seconds == second ? .green : .white)
                            .font(seconds == second ? .title : .body)
                            .animation(.easeInOut(duration: 0.1), value: seconds)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 80)
                .opacity(isSecondsFocused ? 1.0 : 0.7)
                .onTapGesture {
                    isSecondsFocused = true
                    isMinutesFocused = false
                    isEditing = true
                }
                
                Text("秒")
                    .font(.caption)
                    .padding(.top, -5)
            }
        }
    }
}

struct ContentView: View {
    // デフォルトの設定時間を定数として定義
    private let defaultMinutes = 0
    private let defaultSeconds = 10
    
    @State private var selectedMinutes = 0  // 初期値をdefaultMinutesと同じに
    @State private var selectedSeconds = 10  // 初期値をdefaultSecondsと同じに
    @State private var timeRemaining = 10
    @State private var timer: Timer?
    @State private var hapticTimer: Timer?
    @State private var endTime: Date?
    @State private var isRunning = false
    @State private var isMinutesPickerFocused = false
    @State private var isSecondsPickerFocused = false
    @State private var isEditing = true
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 5) {
                    TimePickerView(
                        minutes: $selectedMinutes,
                        seconds: $selectedSeconds,
                        isMinutesFocused: $isMinutesPickerFocused,
                        isSecondsFocused: $isSecondsPickerFocused,
                        isEditing: $isEditing
                    )
                    .onChange(of: selectedMinutes) { oldValue, newValue in 
                        updateTimeRemaining()
                        updateEndTime()
                    }
                    .onChange(of: selectedSeconds) { oldValue, newValue in 
                        updateTimeRemaining()
                        updateEndTime()
                    }
                    
                    // 3分以上の場合のみ終了時刻を表示
                    if let endTime = endTime, selectedMinutes * 60 + selectedSeconds >= 180 {
                        Text("終了時刻 " + endTime.formatted(.dateTime
                            .month(.defaultDigits)
                            .day(.defaultDigits)
                            .hour()
                            .minute()
                            .locale(Locale(identifier: "ja_JP"))
                        ))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 5)
                    }

                    Button(action: {
                        isMinutesPickerFocused = false
                        isSecondsPickerFocused = false
                        isEditing = false
                        
                        if isRunning {
                            pauseTimer()
                        } else {
                            startCountdown()
                        }
                    }) {
                        Text(isRunning ? "一時停止" : "開始")
                    }
                    .buttonStyle(BorderedButtonStyle(tint: isRunning ? .gray : .orange))
                }
                .padding(.top, 0)
                .frame(minHeight: geometry.size.height)
            }
            .scrollDisabled(geometry.size.height >= geometry.frame(in: .global).height)
            .onAppear {
                startAppAlert()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    func updateTimeRemaining() {
        // 分と秒を合計して残り時間を設定
        timeRemaining = selectedMinutes * 60 + selectedSeconds
    }

    func updateEndTime() {
        let totalSeconds = selectedMinutes * 60 + selectedSeconds
        endTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
    }

    func startCountdown() {
        timer?.invalidate()
        if !isRunning {
            // タイマーが停止状態から開始される場合のみ初期化
            timeRemaining = selectedMinutes * 60 + selectedSeconds
            updateEndTime()
        }
        
        // タイマー開始時の触覚フィードバック
        WKInterfaceDevice.current().play(.start)
        
        isRunning = true
        isEditing = false  // タイマー開始時に編集状態を解除

        // 1秒ごとにカウントダウンを更新するタイマーを設定
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedMinutes = timeRemaining / 60
                    selectedSeconds = timeRemaining % 60
                }
            } else {
                timer?.invalidate()
                isRunning = false
                isEditing = true  // タイマー終了時に編集状態を有効化
                alertTimer()
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isEditing = true  // 一時停止時に編集状態を有効化
        // 一時停止時の触覚フィードバック
        WKInterfaceDevice.current().play(.stop)
    }

    func alertTimer() {
        print("タイマーが終了しました！")
        
        // アラートを表示する
        if let rootController = WKExtension.shared().rootInterfaceController {
            // 既存の触覚フィードバックタイマーを停止
            hapticTimer?.invalidate()
            
            // 触覚フィードバックを開始
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                WKInterfaceDevice.current().play(.failure)
            }
            
            rootController.presentAlert(withTitle: "タイマー終了", message: "タイマーが終了しました！", preferredStyle: .alert, actions: [
                WKAlertAction(title: "OK", style: .default, handler: { 
                    print("OKボタンが押されました！")
                    // OKボタンが押されたら触覚フィードバックを停止
                    self.hapticTimer?.invalidate()
                    self.hapticTimer = nil
                    // デフォルトの設定時間に戻す
                    self.resetToDefault()
                })
            ])
        }
    }

    func resetToDefault() {
        selectedMinutes = defaultMinutes
        selectedSeconds = defaultSeconds
        timeRemaining = defaultMinutes * 60 + defaultSeconds
        updateEndTime()
    }
}

#Preview {
    ContentView()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9"))
            
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra"))
        }
    }
}

func startAppAlert() {
    print("アプリが起動しました！")
    //通知のハプティクスを再生
    WKInterfaceDevice.current().play(.directionUp)
}

// Haptics Preview関数をコメントアウト
//func hapticsPreview() {
//    print("触覚フィードバックの再生を開始します！")
//    
//    // すべての触覚フィードバックを順番に再生する
//    let hapticTypes: [WKHapticType] = [
//        .notification, // 通知
//        .directionUp,  // 上方向
//        .directionDown, // 下方向
//        .success,      // 成功
//        .failure,      // 失敗
//        .retry,        // 再試行
//        .start,        // 開始
//        .stop,         // 停止
//        .click         // クリック
//    ]
//    
//    for haptic in hapticTypes {
//        WKInterfaceDevice.current().play(haptic) // 触覚フィードバックを再生
//        Thread.sleep(forTimeInterval: 1) // 各フィードバックの間に1秒の間隔を空ける
//    }
//}

