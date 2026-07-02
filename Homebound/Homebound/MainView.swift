import SwiftUI
import Supabase
import Combine
import LocalAuthentication
import PhotosUI
import MapKit

// MARK: - 1. DATA MODELS
struct MyTrip: Codable, Identifiable {
    var id: Int?
    let category: String?
    let title: String?
    let subtitle: String?
    let start_date: Date?
    let end_date: Date?
    let from_location: String?
    let to_location: String?
    let confirmation: String?
    let notes: String?
}

struct MyTripInsert: Encodable {
    let category: String
    let title: String
    let subtitle: String
    let start_date: String?
    let end_date: String?
    let from_location: String?
    let to_location: String?
    let confirmation: String?
    let notes: String?
}

struct VaultDoc: Codable, Identifiable {
    let id: Int
    let title: String?
    let doc_type: String?
    let details: String?
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - 2. THE ENGINE
class HomeboundAPI: ObservableObject {
    @Published var myItinerary: [MyTrip] = []
    @Published var vaultDocs: [VaultDoc] = []
    @Published var isLoading = false
    @Published var showConfetti = 0
    
    // Replace with your actual credentials
    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://yqglzsujfpipulgkroar.supabase.co")!,
        supabaseKey: "sb_publishable_q61nVwZACM-qFP3EPY4sRg_wlD7jK8I"
    )

    @MainActor
    func fetchAllData() async {
        self.isLoading = true
        do {
            async let t: [MyTrip] = try await supabase.from("my_trips").select().order("id", ascending: false).execute().value
            async let v: [VaultDoc] = try await supabase.from("vault_docs").select().order("id", ascending: false).execute().value
            self.myItinerary = try await t
            self.vaultDocs = try await v
        } catch {
            print("❌ API Error: \(error)")
        }
        self.isLoading = false
    }

    func addTripItem(
        category: String,
        title: String,
        subtitle: String,
        startDate: Date?,
        endDate: Date?,
        fromLocation: String?,
        toLocation: String?,
        confirmation: String?,
        notes: String?
    ) async {
        let insert = MyTripInsert(
            category: category,
            title: title,
            subtitle: subtitle,
            start_date: startDate?.iso8601String,
            end_date: endDate?.iso8601String,
            from_location: fromLocation,
            to_location: toLocation,
            confirmation: confirmation,
            notes: notes
        )
        do {
            try await supabase.from("my_trips").insert(insert).execute()
            await MainActor.run {
                self.showConfetti += 1
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            await fetchAllData()
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// MARK: - 3. MAIN NAVIGATION
struct MainView: View {
    @StateObject var engine = HomeboundAPI()
    
    var body: some View {
        TabView {
            TripsView(engine: engine)
                .tabItem { Label("Trips", systemImage: "map.fill") }
            ServiceView()
                .tabItem { Label("Services", systemImage: "square.grid.2x2.fill") }
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
            ConnectView()
                .tabItem { Label("Connect", systemImage: "bubble.left.and.bubble.right.fill") }
            VaultView(engine: engine)
                .tabItem { Label("Vault", systemImage: "lock.shield.fill") }
        }
        .accentColor(.orange)
        .preferredColorScheme(.dark)
        .onAppear { Task { await engine.fetchAllData() } }
    }
}

// MARK: - 4. TRIPS VIEW
struct TripsView: View {
    @ObservedObject var engine: HomeboundAPI
    @State private var showSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 25) {
                        NextTripHeroWidget(departure: Date().addingTimeInterval(60*60*24*14))
                            .padding(.horizontal)
                        MinimalTripMapView(
                            origin: CLLocationCoordinate2D(latitude: 38.4237, longitude: 27.1428),
                            destination: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276)
                        ).frame(height: 200).cornerRadius(24).padding(.horizontal)
                        DigitalBoardingPassView(fromCode: "ADB", fromCity: "Izmir", toCode: "LHR", toCity: "London", seat: "1A")
                            .padding(.horizontal)
                        VStack(alignment: .leading) {
                            Text("Your Plans").font(.headline).padding(.leading)
                            if engine.isLoading {
                                ProgressView("Loading trips...").padding()
                            } else if engine.myItinerary.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No trips found.").foregroundColor(.secondary)
                                    Button("Add Example Trip") {
                                        Task {
                                            await engine.addTripItem(
                                                category: "Flight",
                                                title: "Sample Trip",
                                                subtitle: "Demo",
                                                startDate: Date(),
                                                endDate: Date().addingTimeInterval(60*60*24),
                                                fromLocation: "Izmir",
                                                toLocation: "London",
                                                confirmation: "ABC123",
                                                notes: "This is a sample trip."
                                            )
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding()
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(engine.myItinerary) { item in
                                            ItineraryCard(item: item).frame(width: 260)
                                        }
                                    }.padding(.horizontal)
                                }
                            }
                        }
                    }.padding(.bottom, 100)
                }
                if engine.showConfetti > 0 { ConfettiView().ignoresSafeArea() }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showSheet = true }) {
                            Image(systemName: "plus").font(.title.bold()).foregroundColor(.black)
                                .frame(width: 65, height: 65).background(Color.orange).clipShape(Circle())
                        }.padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSheet) { AddTripSheet(engine: engine) }
        }
    }
}

// MARK: - 5. SUB-VIEWS (THE MISSING PIECES)

struct AddTripSheet: View {
    @ObservedObject var engine: HomeboundAPI
    @Environment(\.dismiss) var dismiss

    @State private var category = "Flight"
    @State private var title = ""
    @State private var details = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24)
    @State private var fromLocation = ""
    @State private var toLocation = ""
    @State private var confirmation = ""
    @State private var notes = ""

    @State private var showValidation = false

    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("Flight").tag("Flight")
                        Text("Hotel").tag("Hotel")
                        Text("Activity").tag("Activity")
                        Text("Transport").tag("Transport")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Basics") {
                    TextField("Title (e.g. TK1 to LHR / Marriott Downtown)", text: $title)
                    TextField("Details (e.g. Gate A2 / Room 302)", text: $details)
                }

                Section("When") {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                }

                Section("Where") {
                    TextField("From (City/Airport/Address)", text: $fromLocation)
                    TextField("To (City/Airport/Address)", text: $toLocation)
                }

                Section("Extras") {
                    TextField("Confirmation #", text: $confirmation)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Label("Save Trip", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Please fill the required fields", isPresented: $showValidation) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard isValid else { showValidation = true; return }
        Task {
            await engine.addTripItem(
                category: category,
                title: title,
                subtitle: details,
                startDate: startDate,
                endDate: endDate,
                fromLocation: fromLocation.isEmpty ? nil : fromLocation,
                toLocation: toLocation.isEmpty ? nil : toLocation,
                confirmation: confirmation.isEmpty ? nil : confirmation,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        }
    }
}

struct ItineraryCard: View {
    let item: MyTrip
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category == "Flight" ? "airplane" : item.category == "Hotel" ? "bed.double.fill" : "calendar")
                .foregroundColor(.black)
                .padding(10)
                .background(Color.orange)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "").bold().lineLimit(1)
                if let from = item.from_location, let to = item.to_location, !from.isEmpty || !to.isEmpty {
                    Text("\(from) → \(to)")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.9))
                }
                if let start = item.start_date, let end = item.end_date {
                    Text("\(shortDate(start)) – \(shortDate(end))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else if let sub = item.subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
}

struct NextTripHeroWidget: View {
    let departure: Date
    @State private var breathe = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(Color.orange.opacity(0.15))
            VStack {
                Text("Next Adventure").font(.caption).bold().foregroundColor(.orange)
                Text("14 Days Remaning").font(.title2.bold())
            }
        }
        .frame(height: 180)
        .scaleEffect(breathe ? 1.02 : 0.98)
        .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever()) { breathe = true } }
    }
}

struct MinimalTripMapView: UIViewRepresentable {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(); map.overrideUserInterfaceStyle = .dark
        map.isScrollEnabled = false; map.layer.cornerRadius = 24
        let geodesic = MKGeodesicPolyline(coordinates: [origin, destination], count: 2)
        map.addOverlay(geodesic)
        return map
    }
    func updateUIView(_ uiView: MKMapView, context: Context) {}
}

struct DigitalBoardingPassView: View {
    let fromCode, fromCity, toCode, toCity, seat: String
    @State private var flipped = false
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) { Text(fromCode).font(.title.bold()); Text(fromCity).font(.caption) }
                Spacer(); Image(systemName: "airplane").foregroundColor(.orange); Spacer()
                VStack(alignment: .trailing) { Text(toCode).font(.title.bold()); Text(toCity).font(.caption) }
            }
        }
        .padding().background(.ultraThinMaterial).cornerRadius(24)
        .onTapGesture { withAnimation(.spring()) { flipped.toggle() } }
    }
}

struct ConfettiView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<30) { _ in
                Circle().fill(Color.orange).frame(width: 8, height: 8)
                    .offset(x: CGFloat.random(in: -200...200), y: animate ? 900 : -400)
            }
        }.onAppear { withAnimation(.linear(duration: 3)) { animate = true } }
    }
}

// MARK: - 6. OTHER TABS
struct ServiceView: View {
    var body: some View {
        Text("Services Coming Soon").navigationTitle("Utility")
    }
}

struct SocialView: View {
    struct MessageThread: Identifiable {
        let id = UUID()
        let name: String
        let lastMessage: String
        let time: String
        let icon: String
    }
    let threads: [MessageThread] = [
        .init(name: "Emma Johnson", lastMessage: "See you at the airport!", time: "14:32", icon: "person.circle.fill"),
        .init(name: "James Smith", lastMessage: "Flight delayed by 1h.", time: "13:15", icon: "person.fill"),
        .init(name: "Sophia Lee", lastMessage: "Hotel looks amazing!", time: "Yesterday", icon: "person.crop.circle.fill.badge.checkmark"),
        .init(name: "Liam Chen", lastMessage: "Pics from London?", time: "Mon", icon: "person.circle.fill"),
    ]
    var body: some View {
        NavigationView {
            List(threads) { thread in
                HStack(spacing: 16) {
                    Image(systemName: thread.icon)
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading) {
                        Text(thread.name).font(.headline)
                        Text(thread.lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(thread.time).font(.caption).foregroundColor(.gray)
                }
                .padding(.vertical, 5)
            }
            .navigationTitle("Messages")
        }
    }
}

struct ConnectView: View {
    struct NetOption: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
    }
    let options: [NetOption] = [
        .init(title: "eSIM Purchase", description: "Buy a travel eSIM for instant data.", icon: "simcard.fill"),
        .init(title: "Wi-Fi Finder", description: "See nearby free & paid Wi-Fi hotspots.", icon: "wifi"),
        .init(title: "Roaming Tips", description: "How to avoid high mobile bills abroad.", icon: "globe"),
        .init(title: "Offline Maps", description: "Download maps for offline use.", icon: "map.fill")
    ]
    var body: some View {
        NavigationView {
            List(options) { opt in
                HStack(spacing: 16) {
                    Image(systemName: opt.icon)
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading) {
                        Text(opt.title).font(.headline)
                        Text(opt.description).font(.subheadline).foregroundColor(.secondary)
                    }
                }.padding(.vertical, 5)
            }
            .navigationTitle("Internet Options")
        }
    }
}

struct VaultView: View {
    @ObservedObject var engine: HomeboundAPI
    @State private var isUnlocked = false
    @State private var unlocking = false
    @State private var unlockError: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isUnlocked {
                    if engine.isLoading {
                        ProgressView("Loading Vault...")
                            .padding()
                    } else if engine.vaultDocs.isEmpty {
                        Text("No documents in your vault.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        List(engine.vaultDocs) { doc in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(doc.title ?? "Untitled")
                                    .font(.headline)
                                Text(doc.doc_type ?? "Unknown type")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                if let details = doc.details, !details.isEmpty {
                                    Text(details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)
                    }
                } else {
                    if let err = unlockError {
                        Text(err)
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                    }
                    Button(unlocking ? "Unlocking..." : "Unlock Vault with Face ID/Touch ID") {
                        unlock()
                    }
                    .disabled(unlocking)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Vault")
            .background(Color.black.ignoresSafeArea())
        }
    }

    func unlock() {
        unlocking = true
        unlockError = nil
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock your vault") { success, authenticationError in
                DispatchQueue.main.async {
                    unlocking = false
                    if success {
                        isUnlocked = true
                    } else {
                        unlockError = "Authentication failed. Please try again."
                    }
                }
            }
        } else {
            unlocking = false
            unlockError = "Biometric authentication unavailable."
        }
    }
}
