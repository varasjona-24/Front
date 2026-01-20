/// Mismos origins que el backend detecta + device para imports.
enum SourceOrigin {
  device,
  youtube,
  instagram,
  vimeo,
  reddit,
  telegram,
  x,
  facebook,
  pinterest,
  amino,
  blogger,
  twitch,
  kick,
  snapchat,
  qq,
  threads,
  vk,
  chan4,
  mega,
  generic,
}

extension SourceOriginX on SourceOrigin {
  String get key {
    switch (this) {
      case SourceOrigin.device: return 'device';
      case SourceOrigin.youtube: return 'youtube';
      case SourceOrigin.instagram: return 'instagram';
      case SourceOrigin.vimeo: return 'vimeo';
      case SourceOrigin.reddit: return 'reddit';
      case SourceOrigin.telegram: return 'telegram';
      case SourceOrigin.x: return 'x';
      case SourceOrigin.facebook: return 'facebook';
      case SourceOrigin.pinterest: return 'pinterest';
      case SourceOrigin.amino: return 'amino';
      case SourceOrigin.blogger: return 'blogger';
      case SourceOrigin.twitch: return 'twitch';
      case SourceOrigin.kick: return 'kick';
      case SourceOrigin.snapchat: return 'snapchat';
      case SourceOrigin.qq: return 'qq';
      case SourceOrigin.threads: return 'threads';
      case SourceOrigin.vk: return 'vk';
      case SourceOrigin.chan4: return '4chan';
      case SourceOrigin.mega: return 'mega';
      case SourceOrigin.generic: return 'generic';
    }
  }

  static SourceOrigin fromKey(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    switch (s) {
      case 'device': return SourceOrigin.device;
      case 'youtube': return SourceOrigin.youtube;
      case 'instagram': return SourceOrigin.instagram;
      case 'vimeo': return SourceOrigin.vimeo;
      case 'reddit': return SourceOrigin.reddit;
      case 'telegram': return SourceOrigin.telegram;
      case 'x':
      case 'twitter': return SourceOrigin.x;
      case 'facebook': return SourceOrigin.facebook;
      case 'pinterest': return SourceOrigin.pinterest;
      case 'amino': return SourceOrigin.amino;
      case 'blogger':
      case 'blogspot': return SourceOrigin.blogger;
      case 'twitch': return SourceOrigin.twitch;
      case 'kick': return SourceOrigin.kick;
      case 'snapchat': return SourceOrigin.snapchat;
      case 'qq': return SourceOrigin.qq;
      case 'threads': return SourceOrigin.threads;
      case 'vk': return SourceOrigin.vk;
      case '4chan':
      case 'chan4': return SourceOrigin.chan4;
      case 'mega':
      case 'mega.nz': return SourceOrigin.mega;
      default: return SourceOrigin.generic;
    }
  }
}
