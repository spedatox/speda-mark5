# SPEDA File Upload & Vision - Kullanım Kılavuzu

## 🎯 Özellikler

### ✅ Eklendi
1. **File Upload API** - `/api/files/upload`
2. **GPT-4 Vision Analizi** - `/api/files/analyze-image`
3. **URL Image Analizi** - `/api/files/analyze-url`
4. **Flutter File Picker** - Zaten çalışıyor!

## 📱 Flutter'da Kullanım

### 1. Resim Göndermek (Chat'te)
```dart
// Chat screen'de zaten var!
// Dosya seç butonu > Resim seç > Görseli açıkla
```

### 2. API Service ile
```dart
final apiService = context.read<ApiService>();

// Resim yükle ve analiz et
final result = await apiService.uploadFile(
  imagePath,
  analyze: true,
  prompt: 'Bu resimde ne var?',
);

// veya direkt analiz
final description = await apiService.analyzeImage(
  imagePath,
  prompt: 'Bu görüntüyü detaylı açıkla',
);
```

## 🧪 Test (Backend)

### cURL ile Test
```bash
# 1. Resim yükle ve analiz et
curl -X POST https://speda.spedatox.systems/api/files/upload \
  -H "X-API-Key: sk-speda-prod-api-2025" \
  -F "file=@/path/to/image.jpg" \
  -F "analyze=true" \
  -F "prompt=Bu resimde ne var?"

# 2. URL'den resim analizi
curl -X POST https://speda.spedatox.systems/api/files/analyze-url \
  -H "X-API-Key: sk-speda-prod-api-2025" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/image.jpg",
    "prompt": "Bu görüntüyü açıkla"
  }'

# 3. Dosyaları listele
curl https://speda.spedatox.systems/api/files/ \
  -H "X-API-Key: sk-speda-prod-api-2025"
```

### PowerShell ile Test
```powershell
# Resim yükle
$file = "C:\Users\speda\Pictures\test.jpg"
$uri = "https://speda.spedatox.systems/api/files/upload"
$headers = @{"X-API-Key" = "sk-speda-prod-api-2025"}

$form = @{
    file = Get-Item $file
    analyze = "true"
    prompt = "Bu resimde ne var? Detaylı açıkla."
}

Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Form $form
```

## 🎨 Desteklenen Dosya Tipleri

### Görüntüler (Vision destekli)
- ✅ JPEG (.jpg, .jpeg)
- ✅ PNG (.png)
- ✅ GIF (.gif)
- ✅ WebP (.webp)

### Diğer (Gelecek)
- 📄 PDF (.pdf) - Text extraction
- 📝 Text (.txt, .md)
- 🎵 Audio (.mp3, .wav) - Transkripsiyon

## 💡 Örnek Kullanım Senaryoları

### 1. Ekran Görüntüsü Analizi
```dart
// Hata mesajı ekran görüntüsü at
"Bu hatayı çöz"
```

### 2. Diyagram Açıklama
```dart
// Akış diyagramı göster
"Bu akışı açıkla ve iyileştir"
```

### 3. Fotoğraf Sorgulama
```dart
// Fotoğraf yükle
"Bu kişiler kim? Ne yapıyorlar?"
```

### 4. Kod Screenshot'u
```dart
// Kod ekran görüntüsü
"Bu kodda hata var mı?"
```

## 🔧 Sorun Giderme

### "Failed to upload file"
- API key'i kontrol et
- Dosya boyutu 20MB'ı geçmesin
- Dosya formatı destekleniyor mu?

### "Vision analysis failed"
- OpenAI API key geçerli mi?
- Model: `gpt-4o` kullanılıyor
- Görüntü formatı destekleniyor mu?

### Frontend'de görmüyorum
- GitHub Actions deploy tamamlandı mı?
- Backend'de `/api/files/` endpoint'i çalışıyor mu?
- Flutter app'i yeniden başlat

## 📊 Performans

- **Upload hızı**: ~1MB/sn
- **Vision analiz**: 3-10 saniye
- **Cache**: Aynı dosya tekrar yüklenirse hızlı
- **Limit**: 20MB/dosya

## 🚀 Sonraki Adımlar

1. ✅ File upload - TAMAMLANDI
2. ✅ Vision analizi - TAMAMLANDI  
3. 🔜 PDF okuma ve özetleme
4. 🔜 Audio transkripsiyon
5. 🔜 Dosya OCR (taranan dokümanlar)
6. 🔜 Batch upload (çoklu dosya)

---

**Deploy durumu**: GitHub Actions çalışıyor, backend güncellenecek.

**Test için**: Uygulamayı aç > Chat > 📎 ikonu > Resim seç > Gönder
