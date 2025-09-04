import { Injectable } from '@angular/core';
import { DocumentScanner } from '@capacitor-mlkit/document-scanner';
import { registerPlugin, Capacitor } from '@capacitor/core';

const DocumentScannerIOS = registerPlugin<any>('DocumentScannerIOS');

@Injectable({
  providedIn: 'root',
})
export class DocumentScannerService {
  async scanDocument() {
    if (Capacitor.getPlatform() === 'ios') {
      return await DocumentScannerIOS.scan({
        resultFormats: 'JPEG_PDF',
        jpegQuality: 0.9,
        maxDimension: 2000,
      }).then((res: any) => {
        console.log('Scanned images (iOS):', res.imagesBase64);
        console.log('PDF info (iOS):', res.pdfBase64);
      });
    }

    const { available } =
      await DocumentScanner.isGoogleDocumentScannerModuleAvailable();

    if (!available) {
      console.log('Google Document Scanner module is not available.');

      this.installGoogleDocumentScannerModule();

      return;
    }

    const result = await DocumentScanner.scanDocument({
      galleryImportAllowed: true,
      pageLimit: 5,
      resultFormats: 'JPEG_PDF',
      scannerMode: 'BASE',
    });

    console.log('Scanned images:', result.scannedImages);
    console.log('PDF info:', result.pdf);
  }

  private async scanIOS() {
    if (Capacitor.getPlatform() !== 'ios') return;

    // Acceso directo al plugin in-app
    const bridge: any = (window as any)?.Capacitor?.Plugins?.DocumentScannerIOS;
    if (!bridge?.scan) {
      throw new Error('DocumentScannerIOS plugin not available');
    }

    const res = await bridge.scan({
      resultFormats: 'JPEG_PDF', // 'JPEG' | 'PDF' | 'JPEG_PDF'
      jpegQuality: 0.9,
      maxDimension: 2000, // opcional: reduce tamaño/memoria
    });

    // res.imagesBase64?: string[], res.pdfBase64?: string
    return res;
  }

  async isGoogleDocumentScannerModuleAvailable() {
    const result =
      await DocumentScanner.isGoogleDocumentScannerModuleAvailable();
    console.log(
      'Is Google Document Scanner module available:',
      result.available
    );
  }

  async installGoogleDocumentScannerModule() {
    await DocumentScanner.installGoogleDocumentScannerModule();
    console.log('Google Document Scanner module installation started.');
  }
}
