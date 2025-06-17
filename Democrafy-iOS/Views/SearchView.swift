import SwiftUI

struct SearchView: View {
    @StateObject var vm: SearchViewModel
    let room: PartyRoom

    var body: some View {
        VStack {
            TextField("Search Spotify…", text: $vm.query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            List(vm.results) { track in
                HStack {
                    VStack(alignment: .leading) {
                        Text(track.name)
                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { vm.suggest(track: track, in: room) }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("Search")
    }
}
