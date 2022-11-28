import 'package:id3_codec/byte_codec.dart';
import 'package:id3_codec/encode_metadata.dart';
import 'package:id3_codec/image_type.dart';

// https://id3.org/d3v2.3.0
class ContentEncoder {
  const ContentEncoder({
    this.body
  });

  final MetadataEditableWrapper? body;

  /// encode `MetadataV2Body` to bytes
  List<int> encode() {
    assert(body != null);
    List<int> output = [];
    if (body is MetadataV2_3Wrapper) {
      final v2_3Body = body as MetadataV2_3Wrapper;
      if (v2_3Body.title.value != null) {
        output.addAll(
          encodeProperty(frameID: 'TIT2', property: v2_3Body.title)
        );
      }
      if (v2_3Body.artist.value != null) {
        output.addAll(
          encodeProperty(frameID: 'TPE1', property: v2_3Body.artist)
        );
      }
      if (v2_3Body.album.value != null) {
        output.addAll(
          encodeProperty(frameID: 'TALB', property: v2_3Body.album)
        );
      } 
      if (v2_3Body.encoding.value != null) {
        output.addAll(
          encodeProperty(frameID: 'TSSE', property: v2_3Body.encoding)
        );
      }
      if (v2_3Body.userDefines.value != null) {
        for (final entry in v2_3Body.userDefines.value!) {
          output.addAll(
            encodeProperty(frameID: 'TXXX', property: entry)
          );
        }
      }
      if (v2_3Body.imageBytes.value != null && ImageCodec.getImageMimeType(v2_3Body.imageBytes.value!).isNotEmpty) {
        output.addAll(
          encodeProperty(frameID: 'APIC', property: v2_3Body.imageBytes)
        );
      }
    }
    return output;
  }


  /// Encode the content corresponding to frameID.
  /// - frameID: frame identifier
  /// - content: encode content, read from EncodeMetadataV2Body's properties
  /// 
  /// Unless you know what you're encoding the property, don't actively call it
  List<int> encodeProperty({required String frameID, required MetadataProperty property}) {
    if (property.value == null || property.attached) return [];
    _ContentEncoder? encoder;
    if (frameID == 'TXXX') {
      encoder = _TXXXEncoder(frameID);
    } else if (frameID.startsWith('T')) {
      encoder = _TextInfomationEncoder(frameID);
    } else if (frameID == 'APIC') {
      encoder = _APICEncoder(frameID);
    }
    if (encoder != null) {
      property.attached = true;
    }
    return encoder?.encode(property.value) ?? [];
  }
}

abstract class _ContentEncoder {
  const _ContentEncoder(this.frameID);

  final String frameID;

  List<int> encode(dynamic content);
}

/*
  <Header for 'Text information frame', ID: "T000" - "TZZZ",
     excluding "TXXX" described in 4.2.2.>
     Text encoding                $xx
     Information                  <text string according to encoding>
*/
class _TextInfomationEncoder extends _ContentEncoder {
  _TextInfomationEncoder(super.frameID);

  @override
  List<int> encode(content) {
    List<int> output = [];

    // set text encoding 'UTF16'
    const defaultTextEncoding = 0x01;
    final codec = ByteCodec(textEncodingByte: defaultTextEncoding);

    // text encoding
    output.add(defaultTextEncoding);

    // information
    final infoBytes = codec.encode(content);
    output.addAll(infoBytes);

    return output;
  }

}

/*
  <Header for 'User defined text information frame', ID: "TXXX">
     Text encoding     $xx
     Description       <text string according to encoding> $00 (00)
     Value             <text string according to encoding>
*/
class _TXXXEncoder extends _ContentEncoder {
  _TXXXEncoder(super.frameID);
  
  @override
  List<int> encode(content) {
    if (content !is MapEntry) return [];
    List<int> output = [];

    // set text encoding 'UTF16'
    const defaultTextEncoding = 0x01;
    final codec = ByteCodec(textEncodingByte: defaultTextEncoding);

    // text encoding
    output.add(defaultTextEncoding);

    // Description
    final decBytes = codec.encode(content.key);
    output.addAll(decBytes);
    output.addAll([0x00, 0x00]);

    // Value
    final valueBytes = codec.encode(content.value);
    output.addAll(valueBytes);

    return output;
  }
  
}

/*
       <Header for 'Attached picture', ID: "APIC">
     Text encoding      $xx
     MIME type          <text string> $00
     Picture type       $xx
     Description        <text string according to encoding> $00 (00)
     Picture data       <binary data>
*/
class _APICEncoder extends _ContentEncoder {
  _APICEncoder(super.frameID);

  @override
  List<int> encode(content) {
    List<int> output = [];

    // set text encoding 'ISO_8859_1'
    const defaultTextEncoding = 0x00;
    final codec = ByteCodec(textEncodingByte: defaultTextEncoding);

    // text encoding
    output.add(defaultTextEncoding);

    // MIME type
    String mimeType = ImageCodec.getImageMimeType(content);
    final mimeBytes = codec.encode(mimeType, forceType: ByteCodecType.ISO_8859_1);
    output.addAll(mimeBytes);
    output.add(0x00);

    // Picture type, default set to 'Other'
    final pictypeBytes = 0x00;
    output.add(pictypeBytes);

    // Description
    if (defaultTextEncoding == 0x01 || defaultTextEncoding == 0x02) {
      output.addAll([0x00, 0x00]);
    } else {
      output.addAll([0x00]);
    }

    // Picture data
    output.addAll(content);

    return output;
  }
}