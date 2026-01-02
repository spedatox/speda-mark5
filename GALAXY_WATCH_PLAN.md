# SPEDA Galaxy Watch 6 Classic - WearOS App

## Project Structure
```
speda-watch/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── java/com/spedatox/watch/
│   │       │   ├── MainActivity.kt
│   │       │   ├── SpedaService.kt
│   │       │   ├── NotificationListener.kt
│   │       │   └── ComplicationProvider.kt
│   │       ├── res/
│   │       │   ├── layout/
│   │       │   ├── values/
│   │       │   └── drawable/
│   │       └── AndroidManifest.xml
│   └── build.gradle
├── gradle/
└── settings.gradle
```

## Features

### Phase 1 - Essentials (Week 1)
- [ ] **Notification Sync** - Telefondaki SPEDA bildirimlerini saat'e göster
- [ ] **Quick Actions** - Hızlı komutlar (Briefing, Task listesi, Bugünkü plan)
- [ ] **Complication** - Saat kadranında mini widget (Görev sayısı, Toplantı)
- [ ] **Voice Commands** - "Hey SPEDA" ile komut ver

### Phase 2 - Intelligence (Week 2)
- [ ] **Proaktif Hatırlatmalar** - Toplantı 15dk önce titreşim + öneriler
- [ ] **Health Data** - Samsung Health entegrasyonu (Kalp atışı, aktivite)
- [ ] **Context Awareness** - Konum bazlı öneriler
- [ ] **Smart Replies** - Hızlı yanıt önerileri

### Phase 3 - Advanced (Week 3+)
- [ ] **Standalone Mode** - Telefonsuz çalışabilme (LTE Watch)
- [ ] **Voice Recording** - Notları sesle kaydet
- [ ] **Calendar View** - Tam takvim görünümü
- [ ] **Task Management** - Görev ekle/tamamla

## Tech Stack
- **Language**: Kotlin
- **Framework**: Jetpack Compose for WearOS
- **Architecture**: MVVM + Clean Architecture
- **Networking**: Retrofit + OkHttp
- **Storage**: Room Database (offline cache)
- **Auth**: Shared token with mobile app
- **Push**: Firebase Cloud Messaging

## API Integration
```kotlin
class SpedaApiService {
    private val baseUrl = "https://speda.spedatox.systems/api"
    
    suspend fun getDailyBriefing(): Briefing
    suspend fun getTasks(): List<Task>
    suspend fun getUpcomingEvents(): List<Event>
    suspend fun sendVoiceCommand(audio: ByteArray): Response
}
```

## Samsung Health Integration
```kotlin
class HealthDataService {
    fun getHeartRate(): Int
    fun getSteps(): Int
    fun getActivity(): ActivityLevel
    
    // Send to SPEDA for context-aware suggestions
    suspend fun syncHealthData()
}
```

## Complications (Watch Face Widget)
```kotlin
// Show on watch face:
// - Next meeting time
// - Pending tasks count
// - Today's weather
// - SPEDA status indicator
```

## Voice Commands
```
"Hey SPEDA"
- "Bugünkü planım ne?"
- "Görevlerimi göster"
- "Sonraki toplantım ne zaman?"
- "Hava nasıl?"
- "Yalova'da şehit haberi var mı?" (web search)
```

## Battery Optimization
- Use Work Manager for background sync
- Limit updates to every 15 minutes
- Use Doze mode exceptions wisely
- Cache data locally

## Development Plan

### Week 1: Foundation
```bash
# 1. Create WearOS project
# 2. Setup API communication
# 3. Implement notification listener
# 4. Basic UI with Compose
```

### Week 2: Intelligence
```bash
# 1. Proactive scheduler integration
# 2. Voice command handling
# 3. Samsung Health data sync
# 4. Context-aware suggestions
```

### Week 3: Polish
```bash
# 1. Complications
# 2. Standalone mode
# 3. Offline support
# 4. Battery optimization
```

## Next Steps
1. **Setup WearOS Development Environment**
   - Android Studio
   - WearOS emulator or physical device
   - Galaxy Watch SDK

2. **Create Project**
   ```bash
   # Create new WearOS project in Android Studio
   # Select "Empty Wearable Activity"
   # Min SDK: API 30 (Android 11 - WearOS 3.0)
   ```

3. **Test on Galaxy Watch 6 Classic**
   - Enable Developer Mode
   - Connect via ADB
   - Install test builds

**Ready to start?** Hangi feature'dan başlayalım?
