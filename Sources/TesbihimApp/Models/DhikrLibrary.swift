import Foundation

/// Hazır zikir kütüphanesi — bkz. PLAN.md Bölüm 6 Faz 1, Bölüm 7.2.
///
/// **Editoryel not**: buradaki Arapça/Türkçe okunuş/anlam metinleri
/// yaygın, standart zikir/tesbih ifadeleridir; yine de Bölüm 6'daki
/// "içerik editoryel süreci" (kaynak, sorumlu kişi, sürüm tarihi,
/// düzeltme prosedürü) tanımlanıp bu taslak yayın öncesi bir dini içerik
/// sorumlusu tarafından satır satır doğrulanmadan App Store'a gönderilmemeli.
enum DhikrLibrary {
    static let tesbihat: [DhikrDefinition] = [
        DhikrDefinition(
            id: "subhanallah",
            category: .tesbihat,
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "Sübhanallah",
            meaning: "Allah, her türlü noksanlıktan münezzehtir.",
            defaultTarget: 33,
            source: "Taslak içerik — yayın öncesi dini içerik editoryel süreciyle doğrulanmalı (bkz. PLAN.md Bölüm 6).",
            contentVersion: 1
        ),
        DhikrDefinition(
            id: "elhamdulillah",
            category: .tesbihat,
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Elhamdülillah",
            meaning: "Hamd, yalnızca Allah'a mahsustur.",
            defaultTarget: 33,
            source: "Taslak içerik — yayın öncesi dini içerik editoryel süreciyle doğrulanmalı (bkz. PLAN.md Bölüm 6).",
            contentVersion: 1
        ),
        DhikrDefinition(
            id: "allahuekber",
            category: .tesbihat,
            arabicText: "اللَّهُ أَكْبَرُ",
            transliteration: "Allahu Ekber",
            meaning: "Allah en büyüktür.",
            defaultTarget: 33,
            source: "Taslak içerik — yayın öncesi dini içerik editoryel süreciyle doğrulanmalı (bkz. PLAN.md Bölüm 6).",
            contentVersion: 1
        )
    ]

    static let salavat: [DhikrDefinition] = [
        DhikrDefinition(
            id: "salavat-serife",
            category: .salavat,
            arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
            transliteration: "Allahümme salli alâ Muhammed",
            meaning: "Allah'ım! Muhammed'e salât eyle.",
            defaultTarget: 100,
            source: "Taslak içerik — yayın öncesi dini içerik editoryel süreciyle doğrulanmalı (bkz. PLAN.md Bölüm 6).",
            contentVersion: 1
        )
    ]

    static let istigfar: [DhikrDefinition] = [
        DhikrDefinition(
            id: "estagfirullah",
            category: .istigfar,
            arabicText: "أَسْتَغْفِرُ اللَّهَ",
            transliteration: "Estağfirullah",
            meaning: "Allah'tan bağışlanma dilerim.",
            defaultTarget: 100,
            source: "Taslak içerik — yayın öncesi dini içerik editoryel süreciyle doğrulanmalı (bkz. PLAN.md Bölüm 6).",
            contentVersion: 1
        )
    ]

    static var all: [DhikrDefinition] { tesbihat + salavat + istigfar }

    static func definition(for id: String) -> DhikrDefinition? {
        if id == DhikrDefinition.freeCounter.id { return DhikrDefinition.freeCounter }
        return all.first { $0.id == id }
    }
}
