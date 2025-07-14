import SwiftUI
import CoreText

func registerFont() {
    guard let url = Bundle.main.url(forResource: "Itim-Regular", withExtension: "ttf"),
          let dataProvider = CGDataProvider(url: url as CFURL),
          let font = CGFont(dataProvider) else {
        print("Font not found or invalid")
        return
    }
    CTFontManagerRegisterGraphicsFont(font, nil)
}

extension Color {
    static let leafGreen = Color(red: 52/255, green: 122/255, blue: 84/255)
    static let softGreen = Color(red: 162/255, green: 207/255, blue: 169/255)
    static let mediumGreen = Color(red: 90/255, green: 180/255, blue: 130/255)
    static let softCream = Color(red: 247/255, green: 242/255, blue: 229/255)
    static let darkForest = Color(red: 43/255, green: 77/255, blue: 61/255)
}

enum TaskType: String, CaseIterable, Identifiable {
    case homework = "Homework"
    case selfCare = "Self-Care"
    var id: String { self.rawValue }
}

struct Task: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: TaskType
    let priority: Int
    let dueDate: Date
}

class XPManager: ObservableObject {
    @Published var xp: Int = 0
    @Published var tasks: [Task] = []
    @Published var levelUp: Bool = false
    
    // Store tasks pending completion until TaskListView disappears
    private var pendingCompletions: [Task] = []
    
    let stageThresholds = [0, 20, 40, 60, 80, 100]
    
    var plantStage: Int {
        for (i, threshold) in stageThresholds.enumerated().reversed() {
            if xp >= threshold {
                return i
            }
        }
        return 0
    }
    
    var currentStageXP: Int {
        let current = stageThresholds[plantStage]
        let next = plantStage < stageThresholds.count - 1 ? stageThresholds[plantStage + 1] : current + 20
        return xp - current
    }
    
    var currentStageMax: Int {
        let current = stageThresholds[plantStage]
        let next = plantStage < stageThresholds.count - 1 ? stageThresholds[plantStage + 1] : current + 20
        return next - current
    }
    
    var progressFraction: Double {
        Double(currentStageXP) / Double(currentStageMax)
    }
    
    func gainXP(for task: Task) {
        switch task.priority {
        case 1: xp += 3
        case 2: xp += 2
        case 3: xp += 1
        default: break
        }
    }
    
    // Add tasks to pending completions, remove from list immediately so UI updates
    func queueCompletion(tasks toComplete: [Task]) {
        pendingCompletions.append(contentsOf: toComplete)
        tasks.removeAll(where: { toComplete.contains($0) })
    }
    
    // Call this after TaskListView disappears to process XP and animate
    func processPendingCompletions() {
        let oldStage = plantStage
        for task in pendingCompletions {
            gainXP(for: task)
        }
        pendingCompletions.removeAll()
        
        if plantStage > oldStage {
            levelUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.levelUp = false
            }
        }
    }
    
    func tasks(of type: TaskType) -> [Task] {
        tasks.filter { $0.type == type }
    }
}

struct ContentView: View {
    @State private var hideContent = false
    @State private var goNext = false
    @StateObject private var xpManager = XPManager()
    
    init() {
        registerFont()
    }
    
    var body: some View {
        NavigationStack {
            if !goNext {
                VStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(2.7) // smaller image
                        .frame(width: 100, height: 100) // smaller image
                        .offset(x: 5.5, y: hideContent ? -100 : -50) // moved up
                        .opacity(hideContent ? 0 : 1)
                    
                    Button("continue") {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            hideContent = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            goNext = true
                        }
                    }
                    .font(.custom("Itim", size: 24))
                    .foregroundColor(.softCream)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 10)
                    .background(Color.leafGreen)
                    .cornerRadius(30)
                    .opacity(hideContent ? 0 : 1)
                    .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.softCream)
            } else {
                MainMenuView()
            }
        }
        .environmentObject(xpManager)
    }
}

struct MainMenuView: View {
    @EnvironmentObject var xpManager: XPManager
    
    func createShareMessage() -> String {
        return "I just leveled up my plant to Stage \(xpManager.plantStage) in Sproutly! 🌱 I'm at \(xpManager.xp) XP!"
    }

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.softCream.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer().frame(height: 40) // slightly less space
                    
                    VStack(spacing: 10) {
                        Text("Plant Growth")
                            .font(.custom("Itim", size: 22))
                            .foregroundColor(.darkForest)
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 20)
                                .frame(height: 20)
                                .foregroundColor(.softGreen.opacity(0.3))
                            
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: CGFloat(xpManager.progressFraction) * 250, height: 20)
                                .foregroundColor(.leafGreen)
                        }
                        .frame(width: 250)
                        
                        Text("\(xpManager.currentStageXP) / \(xpManager.currentStageMax) XP")
                            .font(.custom("Itim", size: 18))
                            .foregroundColor(.darkForest)
                    }
                    
                    ZStack {
                        Image(xpManager.plantStage == 0 ? "emptyPot" : "\(xpManager.plantStage)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100) // smaller image
                            .scaleEffect(xpManager.levelUp ? 2.5 : 1.7) // scale slightly less
                            .opacity(xpManager.levelUp ? 0 : 1)
                            .animation(.easeInOut(duration: 0.8), value: xpManager.levelUp)
                            .offset(y: 85) // moved up slightly
                            .frame(maxWidth: .infinity)
                    }
                    
                    if xpManager.levelUp {
                        Text("LEVEL UP!")
                            .font(.custom("Itim", size: 40))
                            .foregroundColor(.leafGreen)
                            .transition(.scale.combined(with: .opacity))
                            .offset(y: -50)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

                    NavigationLink(destination: AddTaskView()) {
                        Text("ADD TASK")
                            .font(.custom("Itim", size: 50))
                            .foregroundColor(.softCream)
                            .padding(.horizontal, 80)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 80)
                                    .fill(Color.leafGreen)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 80)
                                            .stroke(Color.darkForest, lineWidth: 4)
                                    )
                            )
                    }
                    .offset(y: 180)  // move the whole button

                    NavigationLink(destination: TaskListView(taskType: .homework)
                        .onDisappear {
                            xpManager.processPendingCompletions()
                        }) {
                            Text("VIEW HOMEWORK TASKS")
                                .font(.custom("Itim", size: 23))
                                .foregroundColor(.darkForest)
                                .padding(.horizontal, 60)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 80)
                                        .stroke(Color.darkForest, lineWidth: 4)
                                        .background(Color.softCream.cornerRadius(80))
                                )
                        }
                        .offset(y: 177)

                    
                    NavigationLink(
                        destination: TaskListView(taskType: .selfCare)
                            .onDisappear {
                                xpManager.processPendingCompletions()
                            }
                    ) {
                        Text("VIEW SELF- CARE TASKS")
                            .font(.custom("Itim", size: 23))
                            .foregroundColor(.darkForest)
                            .padding(.horizontal, 64)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 80)
                                    .stroke(Color.darkForest, lineWidth: 4)
                                    .background(Color.softCream.cornerRadius(80))
                            )
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        print("Self-care tasks tapped")
                    })
                    .offset(y: 175)

                    ShareLink(item: createShareMessage()) {
                        Label("Share Progress", systemImage: "square.and.arrow.up")
                            .font(.custom("Itim", size: 16))
                            .foregroundColor(.leafGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.softCream)
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.3), radius: 3, x: 2, y: 2)
                    }
                    .offset(y: -160)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct AddTaskView: View {
    @EnvironmentObject var xpManager: XPManager
    @Environment(\.dismiss) var dismiss
    @State private var taskName: String = ""
    @State private var selectedType: TaskType = .homework
    @State private var selectedPriority: Int = 2
    @State private var dueDate = Date()
    
    var priorityColor: Color {
        switch selectedPriority {
        case 1: return .leafGreen
        case 2: return .mediumGreen
        case 3: return .softGreen
        default: return .softGreen
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Add Task")
                .font(.custom("Itim", size: 30))
                .foregroundColor(.darkForest)
            
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Task Name")
                    .font(.custom("Itim", size: 20))
                TextField("Enter task name", text: $taskName)
                    .padding()
                    .background(Color.softCream)
                    .cornerRadius(10)
                    .font(.custom("Itim", size: 20))
                    .foregroundColor(.darkForest)
            }
            .padding(.horizontal)
            
            Picker("Task Type", selection: $selectedType) {
                ForEach(TaskType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Priority")
                    .font(.custom("Itim", size: 20))
                Picker("Priority", selection: $selectedPriority) {
                    Text("1 (High)").tag(1)
                    Text("2").tag(2)
                    Text("3 (Low)").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .background(priorityColor.opacity(0.2))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .padding(.horizontal)
            
            Button("Add Task") {
                guard !taskName.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return
                }
                let task = Task(name: taskName, type: selectedType, priority: selectedPriority, dueDate: dueDate)
                xpManager.tasks.append(task)
                taskName = ""
                dismiss()
            }
            .font(.custom("Itim", size: 24))
            .foregroundColor(.softCream)
            .padding()
            .frame(maxWidth: .infinity)
            .background(priorityColor)
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
}

struct TaskListView: View {
    @EnvironmentObject var xpManager: XPManager
    var taskType: TaskType
    
    @State private var selectedTasks: Set<Task> = []
    
    var body: some View {
        VStack {
            List {
                ForEach(xpManager.tasks(of: taskType)) { task in
                    HStack {
                        Button(action: {
                            if selectedTasks.contains(task) {
                                selectedTasks.remove(task)
                            } else {
                                selectedTasks.insert(task)
                            }
                        }) {
                            Image(systemName: selectedTasks.contains(task) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTasks.contains(task) ? .leafGreen : .gray)
                                .font(.title2)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(task.name)
                                .font(.custom("Itim", size: 20))
                                .bold()
                            Text("Due: \(task.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.custom("Itim", size: 16))
                                .foregroundColor(.gray)
                            Text("Priority: \(task.priority)")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            
            if !selectedTasks.isEmpty {
                Button("Complete Selected Tasks") {
                    let toComplete = Array(selectedTasks)
                    xpManager.queueCompletion(tasks: toComplete)
                    selectedTasks.removeAll()
                }
                .font(.custom("Itim", size: 24))
                .foregroundColor(.softCream)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.leafGreen)
                .cornerRadius(15)
                .padding()
            }
        }
        .navigationTitle("\(taskType.rawValue) Tasks")
    }
}
