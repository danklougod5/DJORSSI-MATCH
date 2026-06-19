import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/cv_model.dart';

abstract class CvTemplateBase {
  final String id;
  final String name;

  CvTemplateBase({required this.id, required this.name});

  Future<Uint8List> generatePdf(CvModel cv);

  String sanitizeText(String text) {
    // Supprimer les caractères de contrôle non imprimables qui provoquent des carrés dans le PDF (ex: \x07, \x00, etc.)
    final clean = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    return clean
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('\u00a0', ' ')
        .replaceAll('•', '-')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  PdfColor hexToPdfColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return PdfColor.fromInt(int.parse(buffer.toString(), radix: 16));
  }

  pw.Widget buildBulletText(
    String text,
    PdfColor color,
    PdfColor bulletColor, {
    double fontSize = 9,
    double height = 1.3,
    bool splitByDelimiterIfNoNewline = false,
  }) {
    String cleanText = text.trim();
    if (cleanText.startsWith('[') && cleanText.endsWith(']')) {
      cleanText = cleanText.substring(1, cleanText.length - 1).trim();
    }

    // 1. Split text into initial lines by newline
    final initialLines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    List<String> rawLines = [];

    for (final line in initialLines) {
      // If a line contains typical list delimiters on a single line (like ". -" or " - "), split it!
      if (line.contains(' . - ') || line.contains('. - ') || line.contains(' - ')) {
        final parts = line.split(RegExp(r'\s*\.?\s*-\s+'));
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) {
            rawLines.add(trimmed);
          }
        }
      } else if (splitByDelimiterIfNoNewline && initialLines.length == 1) {
        // Fallback split for skills if they don't have newlines
        if (line.contains('•')) {
          rawLines.addAll(line.split('•').map((l) => l.trim()).where((l) => l.isNotEmpty));
        } else if (line.contains(',')) {
          rawLines.addAll(line.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty));
        } else if (line.contains(';')) {
          rawLines.addAll(line.split(';').map((l) => l.trim()).where((l) => l.isNotEmpty));
        } else if (line.contains('|')) {
          rawLines.addAll(line.split('|').map((l) => l.trim()).where((l) => l.isNotEmpty));
        } else {
          rawLines.add(line);
        }
      } else {
        rawLines.add(line);
      }
    }

    final lines = rawLines.map((line) => sanitizeText(line).trim()).where((line) => line.isNotEmpty).toList();
    
    if (lines.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines.map((line) {
        String cleanLine = line;
        
        // Strip common raw bullet prefixes to avoid rendering boxes for unsupported chars
        while (cleanLine.isNotEmpty) {
          final firstChar = cleanLine[0];
          if (firstChar == '•' ||
              firstChar == '-' ||
              firstChar == '*' ||
              firstChar == '[' ||
              firstChar == '▪' ||
              firstChar == '▫' ||
              firstChar == '◦' ||
              firstChar == '▶' ||
              firstChar == '■' ||
              firstChar == '●' ||
              firstChar == 'o' ||
              firstChar == '·') {
            cleanLine = cleanLine.substring(1).trim();
          } else {
            break;
          }
        }
        
        // Strip common suffixes from the end (like brackets or markdown asterisks)
        while (cleanLine.isNotEmpty) {
          if (cleanLine.endsWith(']')) {
            cleanLine = cleanLine.substring(0, cleanLine.length - 1).trim();
          } else if (cleanLine.endsWith('*')) {
            cleanLine = cleanLine.substring(0, cleanLine.length - 1).trim();
          } else {
            break;
          }
        }
        
        if (cleanLine.isEmpty) return pw.SizedBox();

        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Clean vector bullet
              pw.Container(
                margin: pw.EdgeInsets.only(top: fontSize * 0.4, right: 6),
                width: 3.5,
                height: 3.5,
                decoration: pw.BoxDecoration(
                  color: bulletColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              // Content text
              pw.Expanded(
                child: pw.Text(
                  cleanLine,
                  style: pw.TextStyle(
                    color: color,
                    fontSize: fontSize,
                    height: height,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String formatExperienceHeader(CvExperience exp) {
    final parts = <String>[];
    if (exp.company.isNotEmpty) {
      parts.add('chez ${sanitizeText(exp.company)}');
    }
    if (exp.location.isNotEmpty) {
      parts.add(sanitizeText(exp.location));
    }
    
    final buffer = StringBuffer();
    if (parts.isNotEmpty) {
      buffer.write(' : ${parts.join(' - ')}');
    }
    
    if (exp.startDate.isNotEmpty || exp.endDate.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write(', ');
      } else {
        buffer.write(' : ');
      }
      buffer.write(sanitizeText(exp.startDate));
      if (exp.endDate.isNotEmpty) {
        buffer.write(' à ${sanitizeText(exp.endDate)}');
      }
    }
    return buffer.toString();
  }

  String formatEducationHeader(CvEducation edu) {
    if (edu.institution.isNotEmpty) {
      return ' - ${sanitizeText(edu.institution)}';
    }
    return '';
  }

  pw.Widget buildBulletList(
    List<String> items,
    PdfColor textColor,
    PdfColor bulletColor, {
    double fontSize = 10,
    double height = 1.3,
  }) {
    final sanitizedItems = items.map((item) => sanitizeText(item)).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: sanitizedItems.map((item) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: pw.EdgeInsets.only(top: fontSize * 0.4, right: 6),
                width: 3.5,
                height: 3.5,
                decoration: pw.BoxDecoration(
                  color: bulletColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  item,
                  style: pw.TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    height: height,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static final Map<String, pw.ImageProvider> avatarCache = {};

  Future<pw.ImageProvider?> getAvatarImage(CvModel cv) async {
    if (!cv.personalInfo.showAvatar ||
        cv.personalInfo.profileImageUrl == null ||
        cv.personalInfo.profileImageUrl!.isEmpty) {
      debugPrint('[CV Avatar] showAvatar=${cv.personalInfo.showAvatar}, url=${cv.personalInfo.profileImageUrl}');
      return null;
    }

    final url = cv.personalInfo.profileImageUrl!;
    if (avatarCache.containsKey(url)) {
      debugPrint('[CV Avatar] Image trouvée dans le cache en mémoire : $url');
      return avatarCache[url];
    }

    debugPrint('[CV Avatar] Tentative de chargement de l\'image: $url');

    // Méthode 1 : Téléchargement direct via HTTP
    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('[CV Avatar] HTTP status: ${response.statusCode}, content-type: ${response.headers['content-type']}, taille: ${response.bodyBytes.length} octets');
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final image = pw.MemoryImage(response.bodyBytes);
        avatarCache[url] = image;
        return image;
      }
    } catch (e) {
      debugPrint('[CV Avatar] Erreur HTTP directe: $e');
    }

    // Méthode 2 : Fallback via networkImage (package printing)
    try {
      debugPrint('[CV Avatar] Fallback via networkImage...');
      final image = await networkImage(url);
      debugPrint('[CV Avatar] networkImage réussi !');
      avatarCache[url] = image;
      return image;
    } catch (e) {
      debugPrint('[CV Avatar] Erreur networkImage: $e');
    }

    debugPrint('[CV Avatar] ÉCHEC TOTAL du chargement de l\'image');
    return null;
  }

  pw.Widget buildAvatarWidget(CvPersonalInfo info, pw.ImageProvider? avatarImage, {double size = 60, PdfColor? fallbackBg}) {
    if (!info.showAvatar) return pw.SizedBox();
    
    final bg = fallbackBg ?? PdfColors.grey300;
    
    if (avatarImage != null) {
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          image: pw.DecorationImage(
            image: avatarImage,
            fit: pw.BoxFit.cover,
          ),
        ),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: bg,
        shape: pw.BoxShape.circle,
      ),
    );
  }
}

