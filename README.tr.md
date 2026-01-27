# DodoTidy - macOS Sistem Temizleyici

macOS için yerel bir sistem izleme, disk analizi ve temizleme uygulaması. SwiftUI ile macOS 14+ için geliştirilmiştir.

## Özellikler

- **Kontrol Paneli**: Gerçek zamanlı sistem metrikleri (CPU, bellek, disk, pil, Bluetooth cihazları)
- **Temizleyici**: Önbellekleri, günlükleri ve geçici dosyaları tarayın ve kaldırın
- **Analizci**: Etkileşimli gezinme ile görsel disk alanı analizi
- **Optimize Edici**: Sistem optimizasyon görevleri (DNS temizleme, Spotlight sıfırlama, yazı tipi önbelleği yeniden oluşturma vb.)
- **Uygulamalar**: Yüklü uygulamaları görüntüleyin ve ilgili dosya temizliği ile kaldırın
- **Geçmiş**: Tüm temizleme işlemlerini takip edin
- **Zamanlanmış görevler**: Temizlik rutinlerini otomatikleştirin

## Güvenlik Önlemleri

DodoTidy, verilerinizi korumak için birden fazla güvenlik mekanizmasıyla tasarlanmıştır:

### 1. Çöp kutusuna taşıma (Kurtarılabilir)

Tüm dosya silme işlemleri, dosyaları kalıcı olarak silmek yerine Çöp Kutusuna taşıyan macOS'un `trashItem()` API'sini kullanır. Yanlışlıkla silinen dosyaları her zaman Çöp Kutusundan kurtarabilirsiniz.

### 2. Korumalı yollar

Aşağıdaki yollar varsayılan olarak korunur ve asla temizlenmez:

- `~/Documents` - Belgeleriniz
- `~/Desktop` - Masaüstü dosyaları
- `~/Pictures`, `~/Movies`, `~/Music` - Medya kütüphaneleri
- `~/.ssh`, `~/.gnupg` - Güvenlik anahtarları
- `~/.aws`, `~/.kube` - Bulut kimlik bilgileri
- `~/Library/Keychains` - Sistem anahtar zincirleri
- `~/Library/Application Support/MobileSync` - iOS cihaz yedekleri

Korumalı yolları Ayarlar'dan özelleştirebilirsiniz.

### 3. Güvenli ve yalnızca manuel kategoriler

**Güvenli otomatik temizleme yolları** (zamanlanmış görevler tarafından kullanılır):
- Tarayıcı önbellekleri (Safari, Chrome, Firefox)
- Uygulama önbellekleri (Spotify, Slack, Discord, VS Code, Zoom, Teams)
- Xcode DerivedData

**Yalnızca manuel yollar** (açık kullanıcı eylemi gerektirir, asla otomatik temizlenmez):
- **İndirilenler** - İşlenmemiş önemli dosyalar içerebilir
- **Çöp Kutusu** - Boşaltma GERİ ALINAMAZ
- **Sistem günlükleri** - Sorun giderme için gerekli olabilir
- **Geliştirici önbellekleri** (npm, Yarn, Homebrew, pip, CocoaPods, Gradle, Maven) - Uzun yeniden indirmeler gerektirebilir

### 4. Kuru çalıştırma modu

Hiçbir şeyi silmeden tam olarak hangi dosyaların silineceğini önizlemek için Ayarlar'da "Kuru çalıştırma modu"nu etkinleştirin. Bu şunları gösterir:
- Dosya yolları
- Dosya boyutları
- Değişiklik tarihleri
- Toplam sayı ve boyut

### 5. Dosya yaşı filtresi

Yalnızca belirli bir eşikten daha eski dosyaları temizlemek için minimum dosya yaşı (gün olarak) ayarlayın. Bu, yeni oluşturulan veya değiştirilen dosyaların yanlışlıkla silinmesini önler.

Örnek: Son bir haftada değiştirilmemiş dosyaları temizlemek için 7 gün olarak ayarlayın.

### 6. Zamanlanmış görev onayı

"Zamanlanmış görevleri onayla" etkinleştirildiğinde (varsayılan), zamanlanmış temizleme görevleri:
- Çalışmaya hazır olduğunda bildirim gönderir
- Yürütmeden önce kullanıcı onayını bekler
- Kullanıcı incelemesi olmadan asla otomatik temizleme yapmaz

### 7. Yalnızca kullanıcı alanı işlemleri

DodoTidy tamamen kullanıcı alanında çalışır:
- sudo veya root ayrıcalıkları gerekmez
- Sistem dosyalarını değiştiremez
- Diğer kullanıcıların verilerini etkileyemez
- Tüm işlemler `~/` yollarıyla sınırlıdır

### 8. Güvenli optimize edici komutları

Optimize edici yalnızca iyi bilinen, güvenli sistem komutlarını çalıştırır:
- `dscacheutil -flushcache` - DNS önbelleğini temizle
- `qlmanage -r cache` - Quick Look küçük resimlerini sıfırla
- `lsregister` - Launch Services veritabanını yeniden oluştur

Yıkıcı veya riskli sistem komutları dahil değildir.

## Kurulum

### Homebrew (Önerilen)

```bash
brew tap bluewave-labs/dodotidy
brew install --cask dodotidy
```

### Manuel Kurulum

1. [Releases](https://github.com/bluewave-labs/DodoTidy/releases) sayfasından en son DMG dosyasını indirin
2. DMG dosyasını açın ve DodoTidy'yi Uygulamalar klasörüne sürükleyin
3. İlk açılışta sağ tıklayıp "Aç" seçeneğini seçin (imzasız uygulamalar için gerekli)

Veya şu komutu çalıştırın: `xattr -cr /Applications/DodoTidy.app`

## Gereksinimler

- macOS 14.0 veya üzeri
- Xcode 15.0 veya üzeri (kaynak koddan derleme için)

## Kaynak Koddan Derleme

### XcodeGen Kullanarak (Önerilen)

```bash
# Bağımlılıkları yükle
make install-dependencies

# Xcode projesini oluştur
make generate-project

# Uygulamayı derle
make build

# Uygulamayı çalıştır
make run
```

### Doğrudan Xcode Kullanarak

1. Xcode projesini oluşturmak için `make generate-project` komutunu çalıştırın
2. Xcode'da `DodoTidy.xcodeproj` dosyasını açın
3. Derleyin ve çalıştırın (Cmd+R)

## Proje yapısı

```
DodoTidy/
├── App/
│   ├── DodoTidyApp.swift          # Ana uygulama giriş noktası
│   ├── AppDelegate.swift          # Menü çubuğu yönetimi
│   └── StatusItemManager.swift    # Durum çubuğu simgesi
├── Views/
│   ├── MainWindow/                # Ana pencere görünümleri
│   │   ├── MainWindowView.swift
│   │   ├── SidebarView.swift
│   │   ├── DashboardView.swift
│   │   ├── CleanerView.swift
│   │   ├── AnalyzerView.swift
│   │   ├── OptimizerView.swift
│   │   ├── AppsView.swift
│   │   ├── HistoryView.swift
│   │   └── ScheduledTasksView.swift
│   └── MenuBar/
│       └── MenuBarView.swift      # Menü çubuğu açılır penceresi
├── Services/
│   └── DodoTidyService.swift      # Temel servis sağlayıcıları
├── Models/
│   ├── SystemMetrics.swift        # Sistem metrikleri modelleri
│   └── ScanResult.swift           # Tarama sonucu modelleri
├── Utilities/
│   ├── ProcessRunner.swift        # İşlem yürütme yardımcısı
│   ├── DesignSystem.swift         # Renkler, yazı tipleri, stiller
│   └── Extensions.swift           # Biçimlendirme yardımcıları
└── Resources/
    └── Assets.xcassets            # Uygulama simgeleri
```

## Mimari

Uygulama, sağlayıcı tabanlı bir mimari kullanır:

- **DodoTidyService**: Tüm sağlayıcıları yöneten ana koordinatör
- **StatusProvider**: Yerel macOS API'lerini kullanarak sistem metrikleri toplama
- **AnalyzerProvider**: FileManager kullanarak disk alanı analizi
- **CleanerProvider**: Güvenlik önlemleriyle önbellek ve geçici dosya temizliği
- **OptimizerProvider**: Sistem optimizasyon görevleri
- **UninstallProvider**: İlgili dosya tespiti ile uygulama kaldırma

Tüm sağlayıcılar, reaktif durum yönetimi için Swift'in `@Observable` makrosunu kullanır.

## Ayarlar

Yapılandırmak için uygulama menüsünden veya kenar çubuğundan Ayarlar'a erişin:

- **Genel**: Oturum açılışında başlat, menü çubuğu simgesi, yenileme aralığı
- **Temizleme**: Temizlemeden önce onayla, kuru çalıştırma modu, dosya yaşı filtresi
- **Korumalı yollar**: Asla temizlenmemesi gereken yollar
- **Bildirimler**: Düşük disk alanı uyarıları, zamanlanmış görev bildirimleri

## Tasarım sistemi

- **Ana renk**: #13715B (Yeşil)
- **Arka plan**: #0F1419 (Koyu)
- **Birincil metin**: #F9FAFB
- **Köşe yuvarlaklığı**: 4px
- **Düğme yüksekliği**: 34px

## Lisans

MIT Lisansı
