//
//  IconPickerView.swift
//  MoneyTracker
//
//  Shared icon picker with multicolor SF Symbols support
//

import SwiftUI

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    var useMulticolor: Bool = true

    @State private var searchText = ""
    @State private var selectedCategory: IconCategory = .all

    enum IconCategory: String, CaseIterable {
        case all = "Tutte"
        case finance = "Finanza"
        case shopping = "Shopping"
        case transport = "Trasporti"
        case food = "Cibo"
        case home = "Casa"
        case health = "Salute"
        case entertainment = "Svago"
        case technology = "Tecnologia"
        case nature = "Natura"
        case sports = "Sport"
        case travel = "Viaggi"
        case education = "Istruzione"
        case work = "Lavoro"
        case people = "Persone"
        case objects = "Oggetti"
    }

    // MARK: - Icon Collections by Category

    let financeIcons = [
        "creditcard.fill", "creditcard", "creditcard.trianglebadge.exclamationmark.fill",
        "banknote.fill", "banknote", "dollarsign.circle.fill", "dollarsign.circle",
        "eurosign.circle.fill", "eurosign.circle", "yensign.circle.fill",
        "sterlingsign.circle.fill", "bitcoinsign.circle.fill", "turkishlirasign.circle.fill",
        "indianrupeesign.circle.fill", "rublesign.circle.fill", "francsign.circle.fill",
        "wallet.pass.fill", "wallet.pass", "building.columns.fill", "building.columns",
        "chart.line.uptrend.xyaxis", "chart.bar.fill", "chart.pie.fill",
        "percent", "arrow.up.right", "arrow.down.right",
        "chart.xyaxis.line", "waveform.path.ecg", "plusminus.circle.fill"
    ]

    let shoppingIcons = [
        "cart.fill", "cart", "cart.badge.plus", "cart.badge.minus",
        "bag.fill", "bag", "bag.badge.plus", "bag.badge.minus",
        "basket.fill", "basket", "handbag.fill", "handbag",
        "gift.fill", "gift", "giftcard.fill", "giftcard",
        "tag.fill", "tag", "barcode", "qrcode",
        "creditcard.and.123", "storefront.fill", "storefront",
        "purchased.circle.fill", "shippingbox.fill", "shippingbox"
    ]

    let transportIcons = [
        "car.fill", "car", "car.side.fill", "car.side",
        "bus.fill", "bus", "tram.fill", "tram",
        "airplane", "airplane.departure", "airplane.arrival",
        "ferry.fill", "ferry", "sailboat.fill", "sailboat",
        "bicycle", "scooter", "figure.walk", "figure.run",
        "train.side.front.car", "cablecar.fill", "cablecar",
        "fuelpump.fill", "fuelpump", "ev.charger.fill",
        "parkingsign.circle.fill", "road.lanes", "mappin.circle.fill"
    ]

    let foodIcons = [
        "fork.knife", "fork.knife.circle.fill", "cup.and.saucer.fill", "cup.and.saucer",
        "mug.fill", "mug", "wineglass.fill", "wineglass",
        "birthday.cake.fill", "birthday.cake", "carrot.fill", "carrot",
        "takeoutbag.and.cup.and.straw.fill", "takeoutbag.and.cup.and.straw",
        "popcorn.fill", "popcorn", "frying.pan.fill", "frying.pan",
        "refrigerator.fill", "oven.fill", "microwave.fill",
        "cooktop.fill", "dishwasher.fill"
    ]

    let homeIcons = [
        "house.fill", "house", "house.circle.fill",
        "building.fill", "building", "building.2.fill", "building.2",
        "bed.double.fill", "bed.double", "sofa.fill", "sofa",
        "chair.fill", "chair", "lamp.desk.fill", "lamp.floor.fill",
        "lightbulb.fill", "lightbulb", "fan.fill", "fan",
        "air.conditioner.horizontal.fill", "washer.fill", "dryer.fill",
        "sink.fill", "bathtub.fill", "shower.fill", "toilet.fill",
        "door.left.hand.open", "window.vertical.open", "key.fill"
    ]

    let healthIcons = [
        "heart.fill", "heart", "heart.circle.fill",
        "cross.fill", "cross.circle.fill", "pills.fill", "pills",
        "bandage.fill", "bandage", "syringe.fill", "syringe",
        "stethoscope", "medical.thermometer.fill",
        "brain.head.profile", "brain", "lungs.fill", "lungs",
        "figure.walk.motion", "figure.run", "dumbbell.fill",
        "figure.yoga", "figure.mind.and.body", "figure.meditation"
    ]

    let entertainmentIcons = [
        "gamecontroller.fill", "gamecontroller", "arcade.stick.console.fill",
        "tv.fill", "tv", "play.tv.fill", "appletv.fill",
        "headphones", "headphones.circle.fill", "airpodspro",
        "hifispeaker.fill", "hifispeaker", "homepod.fill",
        "music.note", "music.note.list", "guitars.fill",
        "pianokeys", "film.fill", "film", "clapperboard.fill",
        "ticket.fill", "ticket", "theatermasks.fill",
        "photo.fill", "camera.fill", "video.fill"
    ]

    let technologyIcons = [
        "iphone", "iphone.gen3", "ipad", "macbook",
        "desktopcomputer", "display", "tv.and.mediabox.fill",
        "keyboard.fill", "computermouse.fill", "printer.fill",
        "scanner.fill", "memorychip.fill", "cpu.fill",
        "externaldrive.fill", "internaldrive.fill", "opticaldisc.fill",
        "wifi", "antenna.radiowaves.left.and.right", "network",
        "bolt.horizontal.fill", "powerplug.fill", "cable.connector",
        "apps.iphone", "app.badge.fill", "gear"
    ]

    let natureIcons = [
        "leaf.fill", "leaf", "leaf.circle.fill",
        "tree.fill", "tree", "tree.circle.fill",
        "flame.fill", "flame", "drop.fill", "drop",
        "snowflake", "cloud.fill", "cloud.rain.fill",
        "sun.max.fill", "moon.fill", "moon.stars.fill",
        "sparkles", "wind", "tornado",
        "humidity.fill", "thermometer.sun.fill", "thermometer.snowflake",
        "pawprint.fill", "hare.fill", "tortoise.fill",
        "bird.fill", "fish.fill", "ant.fill", "ladybug.fill"
    ]

    let sportsIcons = [
        "sportscourt.fill", "sportscourt", "figure.run",
        "figure.walk", "figure.hiking", "figure.outdoor.cycle",
        "figure.pool.swim", "figure.skiing.downhill", "figure.snowboarding",
        "figure.golf", "figure.tennis", "figure.basketball",
        "figure.soccer", "figure.american.football", "figure.baseball",
        "soccerball", "basketball.fill", "baseball.fill",
        "tennisball.fill", "volleyball.fill", "football.fill",
        "skateboard.fill", "skis.fill", "snowboard.fill",
        "trophy.fill", "medal.fill", "rosette"
    ]

    let travelIcons = [
        "globe", "globe.americas.fill", "globe.europe.africa.fill",
        "globe.asia.australia.fill", "map.fill", "map",
        "mappin.and.ellipse", "location.fill", "location.circle.fill",
        "compass.drawing", "binoculars.fill", "mountain.2.fill",
        "beach.umbrella.fill", "tent.fill", "backpack.fill",
        "suitcase.fill", "suitcase.rolling.fill", "camera.fill",
        "photo.on.rectangle", "flag.fill", "flag.checkered"
    ]

    let educationIcons = [
        "book.fill", "book", "book.closed.fill", "book.circle.fill",
        "books.vertical.fill", "text.book.closed.fill",
        "graduationcap.fill", "graduationcap", "backpack.fill",
        "pencil", "pencil.circle.fill", "highlighter",
        "ruler.fill", "pencil.and.ruler.fill",
        "brain.head.profile", "lightbulb.fill", "puzzlepiece.fill",
        "globe.desk.fill", "studentdesk", "building.columns.fill"
    ]

    let workIcons = [
        "briefcase.fill", "briefcase", "briefcase.circle.fill",
        "case.fill", "latch.2.case.fill", "suitcase.fill",
        "doc.fill", "doc.text.fill", "folder.fill", "folder.circle.fill",
        "tray.fill", "tray.2.fill", "archivebox.fill",
        "paperclip", "link", "pin.fill",
        "calendar", "calendar.circle.fill", "clock.fill",
        "envelope.fill", "phone.fill", "video.fill",
        "person.crop.circle.fill", "person.2.fill", "person.3.fill"
    ]

    let peopleIcons = [
        "person.fill", "person", "person.circle.fill",
        "person.2.fill", "person.3.fill", "person.3.sequence.fill",
        "figure.stand", "figure.wave", "figure.arms.open",
        "figure.2.arms.open", "figure.2.and.child.holdinghands",
        "figure.and.child.holdinghands", "person.and.background.dotted",
        "person.crop.rectangle.fill", "person.text.rectangle.fill",
        "hands.clap.fill", "hand.wave.fill", "hand.thumbsup.fill",
        "hand.thumbsdown.fill", "hand.raised.fill", "hand.point.right.fill"
    ]

    let objectsIcons = [
        "umbrella.fill", "umbrella", "glasses",
        "eyeglasses", "facemask.fill", "tshirt.fill",
        "shoe.fill", "shoe.2.fill", "comb.fill",
        "crown.fill", "wand.and.stars", "wand.and.rays",
        "bell.fill", "bell.badge.fill", "alarm.fill",
        "stopwatch.fill", "timer", "hourglass",
        "battery.100", "battery.50", "battery.25",
        "bolt.fill", "flashlight.on.fill", "flashlight.off.fill",
        "wrench.fill", "hammer.fill", "screwdriver.fill",
        "paintbrush.fill", "paintpalette.fill", "scissors"
    ]

    var allIcons: [String] {
        financeIcons + shoppingIcons + transportIcons + foodIcons +
        homeIcons + healthIcons + entertainmentIcons + technologyIcons +
        natureIcons + sportsIcons + travelIcons + educationIcons +
        workIcons + peopleIcons + objectsIcons
    }

    var filteredIcons: [String] {
        var icons: [String]

        switch selectedCategory {
        case .all: icons = allIcons
        case .finance: icons = financeIcons
        case .shopping: icons = shoppingIcons
        case .transport: icons = transportIcons
        case .food: icons = foodIcons
        case .home: icons = homeIcons
        case .health: icons = healthIcons
        case .entertainment: icons = entertainmentIcons
        case .technology: icons = technologyIcons
        case .nature: icons = natureIcons
        case .sports: icons = sportsIcons
        case .travel: icons = travelIcons
        case .education: icons = educationIcons
        case .work: icons = workIcons
        case .people: icons = peopleIcons
        case .objects: icons = objectsIcons
        }

        if searchText.isEmpty {
            return icons
        } else {
            return icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    let columns = [
        GridItem(.adaptive(minimum: 55))
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IconCategory.allCases, id: \.self) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = category
                                }
                            } label: {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .semibold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                                    )
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()

                // Icons grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .symbolRenderingMode(useMulticolor ? .multicolor : .monochrome)
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == icon ? Color.accentColor : Color(.systemGray6))
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .searchable(text: $searchText, prompt: "Cerca icona...")
            .navigationTitle("Scegli Icona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    IconPickerView(selectedIcon: .constant("creditcard.fill"))
}
