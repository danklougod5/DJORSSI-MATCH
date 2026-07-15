import { useEffect } from 'react';

export default function StoreRedirect() {
  useEffect(() => {
    const userAgent = navigator.userAgent || navigator.vendor || (window as any).opera;
    
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch";
    const appStoreUrl = "https://apps.apple.com/us/app/djorssi-match/id6767549287";

    if (/android/i.test(userAgent)) {
      window.location.href = playStoreUrl;
    } else if (/iPad|iPhone|iPod/.test(userAgent) && !(window as any).MSStream) {
      window.location.href = appStoreUrl;
    } else {
      // Si l'utilisateur est sur ordinateur (desktop), on le renvoie sur la page d'accueil
      window.location.href = "/";
    }
  }, []);

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center text-white font-sans">
      <div className="flex flex-col items-center gap-4 p-6 text-center max-w-sm">
        <div className="w-12 h-12 border-4 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
        <h2 className="text-xl font-bold mt-2">Redirection vers le Store...</h2>
        <p className="text-slate-400 text-sm">
          Nous détectons votre appareil pour vous ouvrir la page de téléchargement sur Google Play ou l'App Store.
        </p>
      </div>
    </div>
  );
}
