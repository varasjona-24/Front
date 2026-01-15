import 'source_origin.dart';

SourceOrigin detectSourceOriginFromUrl(String url) {
  final u = url.toLowerCase();

  if (u.contains('youtube.com') || u.contains('youtu.be'))
    return SourceOrigin.youtube;
  if (u.contains('instagram.com')) return SourceOrigin.instagram;
  if (u.contains('vimeo.com')) return SourceOrigin.vimeo;
  if (u.contains('reddit.com')) return SourceOrigin.reddit;
  if (u.contains('t.me')) return SourceOrigin.telegram;
  if (u.contains('twitter.com') || u.contains('x.com')) return SourceOrigin.x;
  if (u.contains('facebook.com') || u.contains('fb.watch'))
    return SourceOrigin.facebook;
  if (u.contains('pinterest.')) return SourceOrigin.pinterest;
  if (u.contains('aminoapps.com')) return SourceOrigin.amino;
  if (u.contains('blogspot.') || u.contains('blogger.com'))
    return SourceOrigin.blogger;
  if (u.contains('twitch.tv')) return SourceOrigin.twitch;
  if (u.contains('kick.com')) return SourceOrigin.kick;
  if (u.contains('snapchat.com')) return SourceOrigin.snapchat;
  if (u.contains('qq.com')) return SourceOrigin.qq;
  if (u.contains('threads.net')) return SourceOrigin.threads;
  if (u.contains('vk.com')) return SourceOrigin.vk;
  if (u.contains('4chan.org')) return SourceOrigin.chan4;

  return SourceOrigin.generic;
}
