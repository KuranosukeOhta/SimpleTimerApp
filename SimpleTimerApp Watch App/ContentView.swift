//
//  ContentView.swift
//  SimpleTimerApp Watch App
//
//  Created by Kuranosuke Ohta on 2025/01/12.
//

import SwiftUI
import WatchKit

// バックグラウンド実行のためのセッション管理クラス
class ExtendedRuntimeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = ExtendedRuntimeManager()
    var session: WKExtendedRuntimeSession?
    
    func startSession() {
        session?.invalidate()
        session = WKExtendedRuntimeSession()
        session?.delegate = self
        session?.start()
    }
    
    func stopSession() {
        session?.invalidate()
        session = nil
    }
    
    // 必須のデリゲートメソッド
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("バックグラウンドセッション開始")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("バックグラウンドセッション終了予定")
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        let reasonText = error?.localizedDescription ?? reason.description
        print("バックグラウンドセッション終了理由: \(reasonText)")
    }
}

// 無効化理由の説明を追加
extension WKExtendedRuntimeSessionInvalidationReason {
    var description: String {
        switch self {
        case .error:
            return "セッションの実行を妨げるエラーが発生しました"
        case .none:
            return "セッションは正常に終了しました"
        case .sessionInProgress:
            return "既に実行中のセッションが存在します"
        case .expired:
            return "割り当てられた時間を使い切りました"
        case .resignedFrontmost:
            return "アプリがフォアグラウンドから外れました"
        case .suppressedBySystem:
            return "システムがこのタイプのセッションを許可していません"
        @unknown default:
            return "不明な理由"
        }
    }
}

// タイマーの設定時間を管理する構造体
struct TimerSettings: Codable {
    let minutes: Int
    let seconds: Int
    
    var totalSeconds: Int {
        return minutes * 60 + seconds
    }
}

// UserDefaultsのキーを管理する列挙型
private enum UserDefaultsKeys {
    static let lastTimer = "lastTimer"
}

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
    // デフォルトの設定時間を構造体として定義
    private let defaultSettings = TimerSettings(minutes: 0, seconds: 10)
    
    // 前回設定した時間を保持する変数を追加
    @State private var lastSetMinutes: Int
    @State private var lastSetSeconds: Int
    
    @State private var selectedMinutes: Int
    @State private var selectedSeconds: Int
    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @State private var hapticTimer: Timer?
    @State private var endTime: Date?
    @State private var isRunning = false
    @State private var isMinutesPickerFocused = false
    @State private var isSecondsPickerFocused = false
    @State private var isEditing = true
    
    // イニシャライザを追加
    init() {
        // UserDefaultsから前回の設定を読み込む
        let savedSettings: TimerSettings
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.lastTimer),
           let decoded = try? JSONDecoder().decode(TimerSettings.self, from: data) {
            savedSettings = decoded
        } else {
            savedSettings = defaultSettings
        }
        
        // 状態を初期化
        _lastSetMinutes = State(initialValue: savedSettings.minutes)
        _lastSetSeconds = State(initialValue: savedSettings.seconds)
        _selectedMinutes = State(initialValue: savedSettings.minutes)
        _selectedSeconds = State(initialValue: savedSettings.seconds)
        _timeRemaining = State(initialValue: savedSettings.totalSeconds)
    }
    
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
            // タイマー開始時に現在の設定時間を保存
            lastSetMinutes = selectedMinutes
            lastSetSeconds = selectedSeconds
            timeRemaining = selectedMinutes * 60 + selectedSeconds
            updateEndTime()
            
            // 設定をUserDefaultsに保存
            let settings = TimerSettings(minutes: selectedMinutes, seconds: selectedSeconds)
            if let encoded = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.lastTimer)
                UserDefaults.standard.synchronize()  // 確実に保存するために同期を実行
            }
        }
        
        // バックグラウンド実行セッションを開始
        ExtendedRuntimeManager.shared.startSession()
        
        // タイマー開始時の触覚フィードバック
        WKInterfaceDevice.current().play(.start)
        
        isRunning = true
        isEditing = false

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
                isEditing = true
                // バックグラウンド実行セッションを終了
                ExtendedRuntimeManager.shared.stopSession()
                alertTimer()
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isEditing = true
        // バックグラウンド実行セッションを終了
        ExtendedRuntimeManager.shared.stopSession()
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
                    // 前回設定した時間に戻す
                    self.resetToLastSet()
                })
            ])
        }
    }

    // 前回設定した時間に戻す関数を追加
    func resetToLastSet() {
        selectedMinutes = lastSetMinutes
        selectedSeconds = lastSetSeconds
        timeRemaining = lastSetMinutes * 60 + lastSetSeconds
        updateEndTime()
        
        // 設定をUserDefaultsに保存
        let settings = TimerSettings(minutes: lastSetMinutes, seconds: lastSetSeconds)
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.lastTimer)
            UserDefaults.standard.synchronize()  // 確実に保存するために同期を実行
        }
    }
    
    // デフォルト時間に戻す関数を修正
    func resetToDefault() {
        selectedMinutes = defaultSettings.minutes
        selectedSeconds = defaultSettings.seconds
        timeRemaining = defaultSettings.totalSeconds
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

