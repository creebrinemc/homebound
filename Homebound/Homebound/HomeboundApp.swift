import SwiftUI

@main
struct HomeboundApp: App {
    // CREATE SINGLE INSTANCE HERE
    private let supabase: SupabaseClient = {
        // TEMPORARY: Use environment variables (SET UP SECRETS.XCCONFIG NEXT)
        // FOR NOW: Use placeholders - REPLACE WITH YOUR ACTUAL SECRETS.XCCONFIG SETUP
        guard let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let key = ProcessInfo.processInfo.environment["SUPABASE_KEY"],
              let url = URL(string: urlString) else {
            fatalError("⚠️ Missing Supabase credentials in environment variables")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(HomeboundAPI(supabase: supabase)) // INJECT INSTANCE
                .preferredColorScheme(.dark)
        }
    }
}
