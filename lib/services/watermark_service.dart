import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// 水印服务 - 使用 Flutter Canvas 绘制，支持中文
class WatermarkService {
  /// 给图片添加水印
  static Future<File> addWatermark({
    required File imageFile,
    required String timeStr,
    String? storeInfo,
    String? locationStr,
    double? lat,
    double? lng,
  }) async {
    // 加载原始图片
    final bytes = await imageFile.readAsBytes();
    final ui.Image originalImage = await _loadImage(Uint8List.fromList(bytes));
    
    final width = originalImage.width;
    final height = originalImage.height;
    
    // 创建 Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 绘制原图
    canvas.drawImage(originalImage, Offset.zero, Paint());
    
    // 构建水印文字 - 使用emoji图标
    final lines = <String>[];
    lines.add('🕐 $timeStr');
    
    if (storeInfo != null && storeInfo.isNotEmpty) {
      lines.add('🏪 $storeInfo');
    }
    
    if (locationStr != null && 
        locationStr.isNotEmpty && 
        locationStr != '未知位置' &&
        !locationStr.toLowerCase().contains('lat:')) {
      lines.add('📍 $locationStr');
    }
    
    if (lat != null && lng != null) {
      lines.add('🌐 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');
    }
    
    // 水印样式 - 增大字体
    const padding = 20.0;
    const lineHeight = 56.0;
    const bgPadding = 16.0;
    const fontSize = 36.0;
    
    final bgHeight = lines.length * lineHeight + bgPadding * 2;
    final bgY = height - bgHeight - padding;
    
    // 绘制半透明黑色背景
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(padding, bgY, width - padding * 2, bgHeight),
      bgPaint,
    );
    
    // 绘制文字
    final textPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final y = bgY + bgPadding + (i * lineHeight);
      
      final textStyle = ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      );
      
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: fontSize,
          height: 1.2,
        ),
      )
        ..pushStyle(textStyle)
        ..addText(line);
      
      final paragraph = paragraphBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
      
      canvas.drawParagraph(paragraph, Offset(padding + bgPadding, y));
    }
    
    // 生成图片
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    
    // 转换为 bytes
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return imageFile;
    }
    
    // 保存文件
    final tempDir = await getTemporaryDirectory();
    final outputFile = File('${tempDir.path}/wm_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await outputFile.writeAsBytes(byteData.buffer.asUint8List());
    
    return outputFile;
  }
  
  /// 加载图片
  static Future<ui.Image> _loadImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
