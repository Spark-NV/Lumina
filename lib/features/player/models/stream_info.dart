import 'dart:developer' as developer;

class StreamInfo {
  final String id;
  final String orionId;
  final String magnetLink;
  final int seeds;
  final String quality;
  final String codec;
  final String fileName;
  final String fileSize;
  final List<String> hdrFormats;
  final int audioChannels;
  final String audioSystem;
  final String release;
  final String uploader;
  final String source;
  final bool isAtmos;
  final bool isPack;
  final String showTitle;

  StreamInfo({
    required this.id,
    required this.orionId,
    required this.magnetLink,
    required this.seeds,
    required this.quality,
    required this.codec,
    required this.fileName,
    required this.fileSize,
    required this.hdrFormats,
    required this.audioChannels,
    required this.audioSystem,
    required this.release,
    required this.uploader,
    required this.source,
    required this.isAtmos,
    required this.isPack,
    required this.showTitle,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? '';
      final orionId = json['orionId'] as String? ?? '';
      
      if (id.isEmpty || orionId.isEmpty) {
        developer.log(
          'Warning: Missing required IDs - streamId: $id, orionId: $orionId',
          name: 'StreamInfo',
          level: 900,
        );
      }

      final streamData = json['stream'] as Map<String, dynamic>? ?? {};
      final videoData = json['video'] as Map<String, dynamic>? ?? {};
      final audioData = json['audio'] as Map<String, dynamic>? ?? {};
      final fileData = json['file'] as Map<String, dynamic>? ?? {};
      final metaData = json['meta'] as Map<String, dynamic>? ?? {};
      final links = json['links'] as List? ?? [];

      final sizeInBytes = fileData['size'] as int? ?? 0;
      final sizeInGB = (sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      
      final name = fileData['name'] as String? ?? 'unknown';
      final nameLower = name.toLowerCase();
      
      List<String> hdrFormats = [];
      
      if (RegExp(r'\b(dolby.?vision|dv)\b', caseSensitive: false).hasMatch(nameLower)) {
        hdrFormats.add('Dolby Vision');
      }
      if (RegExp(r'\bhdr.?10.?\+|\bhdr.?10.?plus\b', caseSensitive: false).hasMatch(nameLower)) {
        hdrFormats.add('HDR10+');
      }
      else if (RegExp(r'\bhdr.?10\b', caseSensitive: false).hasMatch(nameLower)) {
        hdrFormats.add('HDR10');
      }
      else if (RegExp(r'\bhdr\b|\.hdr\.', caseSensitive: false).hasMatch(nameLower)) {
        hdrFormats.add('HDR');
      }
      
      if (hdrFormats.isEmpty) {
        hdrFormats.add('SDR');
      }
      
      final audioCodec = audioData['codec']?.toString().toLowerCase() ?? '';
      final isAtmos = audioCodec.contains('ams') || 
                      audioCodec.contains('atmos') ||
                      name.toLowerCase().contains('atmos');

      final isPack = fileData['pack'] as bool? ?? false;
      
      final showData = json['show']?['meta']?['title'] as String? ?? '';
      
      return StreamInfo(
        id: id,
        orionId: orionId,
        magnetLink: links.isNotEmpty ? links.first as String : '',
        seeds: streamData['seeds'] as int? ?? 0,
        quality: videoData['quality'] as String? ?? 'unknown',
        codec: videoData['codec'] as String? ?? 'unknown',
        fileName: name,
        fileSize: '$sizeInGB GB',
        hdrFormats: hdrFormats,
        audioChannels: audioData['channels'] as int? ?? 2,
        audioSystem: audioData['system']?.toString().toUpperCase() ?? 'unknown',
        release: metaData['release']?.toString().toUpperCase() ?? 'unknown',
        uploader: metaData['uploader'] as String? ?? 'unknown',
        source: streamData['source'] as String? ?? 'unknown',
        isAtmos: isAtmos,
        isPack: isPack,
        showTitle: showData,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error in StreamInfo.fromJson: $e',
        name: 'StreamInfo',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );
      developer.log(
        'Problematic JSON: $json',
        name: 'StreamInfo',
        level: 1000,
      );
      rethrow;
    }
  }

  factory StreamInfo.fromOrionResponse(Map<String, dynamic> fullResponse, Map<String, dynamic> streamData) {
    String orionId;
    
    final responseData = fullResponse['response']['data'];
    if (responseData['movie'] != null) {
      orionId = responseData['movie']['id']['orion'] as String;
    } else if (responseData['episode'] != null) {
      orionId = responseData['episode']['id']['orion'] as String;
    } else {
      throw Exception('Neither movie nor episode data found in response');
    }
    
    final enrichedStreamData = {
      ...streamData,
      'orionId': orionId,
    };
    
    return StreamInfo.fromJson(enrichedStreamData);
  }

  factory StreamInfo.fromTorrentioResponse(Map<String, dynamic> json) {
    try {
      final title = json['title'] as String;
      final filename = json['behaviorHints']?['filename'] as String? ?? '';
      
      final qualityMatch = RegExp(r'(\d+p|4K)').firstMatch(json['name'] as String);
      final quality = qualityMatch?.group(1)?.toLowerCase() ?? 'unknown';
      
      final seedsMatch = RegExp(r'👤\s*(\d+)').firstMatch(title);
      final seeds = int.tryParse(seedsMatch?.group(1) ?? '0') ?? 0;
      
      final sizeMatch = RegExp(r'💾\s*([\d.]+)\s*(GB|MB)').firstMatch(title);
      final sizeValue = double.tryParse(sizeMatch?.group(1) ?? '0') ?? 0;
      final sizeUnit = sizeMatch?.group(2) ?? 'MB';
      final fileSize = '$sizeValue $sizeUnit';
      
      final sourceMatch = RegExp(r'⚙️\s*(.+)$').firstMatch(title);
      final source = sourceMatch?.group(1)?.trim() ?? 'unknown';
      
      List<String> hdrFormats = [];
      final filenameLower = filename.toLowerCase();
      
      if (RegExp(r'\b(dolby.?vision|dv)\b').hasMatch(filenameLower)) {
        hdrFormats.add('Dolby Vision');
      }
      if (RegExp(r'\bhdr.?10.?\+|\bhdr.?10.?plus\b').hasMatch(filenameLower)) {
        hdrFormats.add('HDR10+');
      }
      else if (RegExp(r'\bhdr.?10\b').hasMatch(filenameLower)) {
        hdrFormats.add('HDR10');
      }
      else if (RegExp(r'\bhdr\b|\.hdr\.').hasMatch(filenameLower)) {
        hdrFormats.add('HDR');
      }
      
      if (hdrFormats.isEmpty) {
        hdrFormats.add('SDR');
      }
      
      final bingeGroup = (json['behaviorHints']?['bingeGroup'] as String? ?? '').split('|');
      String codec = 'unknown';
      String release = 'unknown';
      
      if (bingeGroup.length > 2) {
        release = bingeGroup[2];
      }
      
      final codecMatch = RegExp(r'x264|x265|HEVC').firstMatch(filename);
      if (codecMatch != null) {
        codec = codecMatch.group(0)!;
      }
      
      return StreamInfo(
        id: json['url'] as String,
        orionId: '',
        magnetLink: '',
        seeds: seeds,
        quality: quality,
        codec: codec,
        fileName: filename,
        fileSize: fileSize,
        hdrFormats: hdrFormats,
        audioChannels: 2,
        audioSystem: 'AAC',
        release: release,
        uploader: source,
        source: 'torrentio',
        isAtmos: false,
        isPack: false,
        showTitle: '',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error in StreamInfo.fromTorrentioResponse: $e',
        name: 'StreamInfo',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );
      developer.log(
        'Problematic JSON: ${json.toString()}',
        name: 'StreamInfo',
        level: 1000,
      );
      rethrow;
    }
  }

  String get qualityLabel {
    switch (quality) {
      case 'hd4k':
        return '4K';
      case 'hd1080':
        return '1080p';
      case 'hd720':
        return '720p';
      default:
        return quality.toUpperCase();
    }
  }

  String get displayName {
    final hdrLabel = hdrFormats.isNotEmpty ? ' ${hdrFormats.join(', ')}' : '';
    return '$qualityLabel$hdrLabel | $codec | ${audioChannels}ch $audioSystem | $release';
  }

  bool get isHdr => hdrFormats.isNotEmpty;

  bool isValidForShow(String title) {
    final normalizedStreamTitle = fileName.toLowerCase();
    final normalizedShowTitle = title.toLowerCase();
    
    return normalizedStreamTitle.contains(normalizedShowTitle);
  }
} 