import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

class CvPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const CvPdfViewerScreen({
    Key? key,
    required this.pdfUrl,
    this.title = 'Mon CV',
  }) : super(key: key);

  @override
  State<CvPdfViewerScreen> createState() => _CvPdfViewerScreenState();
}

class _CvPdfViewerScreenState extends State<CvPdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await http.get(Uri.parse(widget.pdfUrl)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pdfBytes = response.bodyBytes;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Impossible de récupérer le fichier PDF (Code ${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible d'ouvrir le CV. Veuillez vérifier votre connexion ou le format du fichier.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFF97316)),
                  SizedBox(height: 16),
                  Text("Chargement du CV...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadPdf,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Réessayer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : PdfPreview(
                  build: (format) => _pdfBytes!,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  useActions: true,
                  allowPrinting: true,
                  allowSharing: true,
                  pdfFileName: 'CV.pdf',
                ),
    );
  }
}
