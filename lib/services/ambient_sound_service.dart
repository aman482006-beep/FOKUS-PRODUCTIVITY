enum AmbientSoundType {
  none,
  rain,
  brownNoise,
  pinkNoise,
  whiteNoise,
  birdsChirping,
  campfire,
  forestAmbience,
  wavesSound,
  underwaterAmbience,
  birdsSingingInRain,
  calmingRain,
  heavyRain,
  thunderRain,
  cafe,
}

extension AmbientSoundTypeExt on AmbientSoundType {
  String get title {
    switch (this) {
      case AmbientSoundType.none: return 'No Sound';
      case AmbientSoundType.rain: return 'Calming Rain';
      case AmbientSoundType.brownNoise: return 'Brown Noise';
      case AmbientSoundType.pinkNoise: return 'Pink Noise';
      case AmbientSoundType.whiteNoise: return 'White Noise';
      case AmbientSoundType.birdsChirping: return 'Birds Chirping';
      case AmbientSoundType.campfire: return 'Campfire';
      case AmbientSoundType.forestAmbience: return 'Forest Ambience';
      case AmbientSoundType.wavesSound: return 'Waves Sound';
      case AmbientSoundType.underwaterAmbience: return 'Underwater Ambience';
      case AmbientSoundType.birdsSingingInRain: return 'Birds Singing in Rain';
      case AmbientSoundType.calmingRain: return 'Calming Rain';
      case AmbientSoundType.heavyRain: return 'Heavy Rain';
      case AmbientSoundType.thunderRain: return 'Thunder Rain';
      case AmbientSoundType.cafe: return 'Cafe Ambience';
    }
  }

  String get category {
    switch (this) {
      case AmbientSoundType.none: return 'NONE';
      case AmbientSoundType.rain:
      case AmbientSoundType.birdsSingingInRain:
      case AmbientSoundType.calmingRain:
      case AmbientSoundType.heavyRain:
      case AmbientSoundType.thunderRain:
        return 'RAIN';
      case AmbientSoundType.brownNoise:
      case AmbientSoundType.pinkNoise:
      case AmbientSoundType.whiteNoise:
        return 'NOISES';
      case AmbientSoundType.birdsChirping:
      case AmbientSoundType.campfire:
      case AmbientSoundType.forestAmbience:
        return 'FOREST';
      case AmbientSoundType.wavesSound:
      case AmbientSoundType.underwaterAmbience:
        return 'OCEAN';
      case AmbientSoundType.cafe:
        return 'LEGACY';
    }
  }

  String? get assetPath {
    switch (this) {
      case AmbientSoundType.none: return null;
      case AmbientSoundType.rain: return 'assets/sounds/rain/calming_rain.mp3';
      case AmbientSoundType.brownNoise: return 'assets/sounds/noises/brown_noise.mp3';
      case AmbientSoundType.pinkNoise: return 'assets/sounds/noises/pink_noise.mp3';
      case AmbientSoundType.whiteNoise: return 'assets/sounds/noises/white_noise.mp3';
      case AmbientSoundType.birdsChirping: return 'assets/sounds/forest/birds_chirping.mp3';
      case AmbientSoundType.campfire: return 'assets/sounds/forest/campfire.mp3';
      case AmbientSoundType.forestAmbience: return 'assets/sounds/forest/forest_ambience.mp3';
      case AmbientSoundType.wavesSound: return 'assets/sounds/ocean/waves_sound.mp3';
      case AmbientSoundType.underwaterAmbience: return 'assets/sounds/ocean/underwater_ambience.mp3';
      case AmbientSoundType.birdsSingingInRain: return 'assets/sounds/rain/birds_singing_in_rain.mp3';
      case AmbientSoundType.calmingRain: return 'assets/sounds/rain/calming_rain.mp3';
      case AmbientSoundType.heavyRain: return 'assets/sounds/rain/heavy_rain.mp3';
      case AmbientSoundType.thunderRain: return 'assets/sounds/rain/thunder_rain.mp3';
      case AmbientSoundType.cafe: return 'assets/sounds/noises/white_noise.mp3'; // Fallback for cafe placeholder
    }
  }
}

class CustomSound {
  final String id;
  final String name;
  final String filePath;
  final String category; // Group section name (e.g. 'Chill', 'Beats')

  CustomSound({
    required this.id,
    required this.name,
    required this.filePath,
    this.category = 'Custom',
  });

  CustomSound copyWith({
    String? name,
    String? filePath,
    String? category,
  }) {
    return CustomSound(
      id: id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'category': category,
      };

  factory CustomSound.fromJson(Map<String, dynamic> json) => CustomSound(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String,
        category: json['category'] as String? ?? 'Custom',
      );
}

