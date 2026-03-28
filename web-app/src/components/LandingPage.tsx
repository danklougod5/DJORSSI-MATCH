import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowRight, CheckCircle, Smartphone, Globe, MessageSquare, PlayCircle, Briefcase, X, Menu } from 'lucide-react';
import AppSimulator from './AppSimulator';






interface FeatureCardProps {
  icon: React.ReactNode;
  title: string;
  description: string;
  colorClass: string;
}

const FeatureCard: React.FC<FeatureCardProps> = ({ icon, title, description, colorClass }) => (
  <div className={`neo-brutal-card ${colorClass}`}>
    <div className="w-16 h-16 bg-white border-black border-2 flex items-center justify-center mb-6 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
      {icon}
    </div>
    <h3 className="text-2xl mb-4 uppercase">{title}</h3>
    <p className="font-medium leading-relaxed">
      {description}
    </p>
  </div>
);

const ComparisonRow: React.FC<{ label: string, free: React.ReactNode, premium: React.ReactNode, isPremium?: boolean }> = ({ label, free, premium, isPremium }) => (
  <div className="grid grid-cols-3 font-bold text-[10px] sm:text-sm leading-tight">
    <div className="p-1.5 sm:p-4 border-r-2 border-black flex items-center bg-white">{label}</div>
    <div className="p-1.5 sm:p-4 border-r-2 border-black text-center flex items-center justify-center bg-white">{free}</div>
    <div className={`p-1.5 sm:p-4 text-center flex items-center justify-center ${isPremium ? 'bg-primary/10 text-primary' : 'bg-white'}`}>{premium}</div>
  </div>
);

const LandingPage: React.FC = () => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isVideoModalOpen, setIsVideoModalOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background selection:bg-accent selection:text-black">
      {/* Navigation */}
      <nav className="fixed top-0 w-full z-50 bg-white border-b-4 border-black transition-all">
        <div className="max-w-7xl mx-auto px-4 md:px-6 h-20 md:h-24 flex items-center justify-between">
          <div className="flex items-center gap-2 md:gap-3">
            <div className="h-10 md:h-12 flex items-center justify-center">
               <img src="/logo.png" alt="Djorssi-Match Logo" className="h-full w-auto object-contain" />
            </div>
            <span className="font-heading text-xl md:text-2xl font-black uppercase tracking-tighter">
              DJORSSI<span className="text-primary hidden sm:inline">-MATCH</span>
            </span>
          </div>

          <div className="hidden md:flex items-center gap-6 font-black uppercase text-sm">
            <a href="#features" className="hover:text-primary transition-colors cursor-pointer">Fonctionnement</a>
            <a href="#premium" className="hover:text-primary transition-colors cursor-pointer">Premium</a>
            <button className="neo-brutal-btn py-2 px-6 text-sm">Télécharger</button>
          </div>
          
          <button 
            className="md:hidden border-2 border-black bg-accent p-2 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
             {isMobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>

        {/* Mobile Nav Content */}
        {isMobileMenuOpen && (
          <div className="md:hidden border-t-4 border-black bg-white flex flex-col font-black uppercase text-sm divide-y-2 divide-black max-h-[calc(100vh-80px)] overflow-y-auto">
            <a href="#features" onClick={() => setIsMobileMenuOpen(false)} className="p-4 hover:bg-slate-100 transition-colors">Fonctionnement</a>
            <a href="#premium" onClick={() => setIsMobileMenuOpen(false)} className="p-4 hover:bg-slate-100 transition-colors">Premium</a>
            <div className="p-4 bg-slate-50">
               <button className="neo-brutal-btn w-full py-3 text-sm">TÉLÉCHARGER MAINTENANT</button>
            </div>
          </div>
        )}
      </nav>

      {/* Hero Section */}
      <section className="relative pt-32 md:pt-40 pb-24 md:pb-32 px-4 md:px-6 overflow-hidden">
        <div className="absolute inset-0 bg-pattern"></div>
        <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 md:gap-16 items-center relative z-10 lg:pl-4">
          <div className="text-left mt-8 md:mt-0">
            <div className="inline-block neo-brutal-tag mb-6 md:mb-8 text-[10px] min-[400px]:text-xs sm:text-sm tracking-tight min-[400px]:tracking-widest leading-relaxed max-w-full whitespace-normal sm:whitespace-nowrap px-4 py-2">
              ⚡️ LE JOB DE TES RÊVES EN UN SWIPE
            </div>
            <h1 className="text-5xl md:text-7xl lg:text-8xl mb-6 md:mb-8 leading-[0.9] text-black italic">
              TROUVE TON <span className="text-primary not-italic">DJORSSI</span> MAINTENANT.
            </h1>
            <p className="text-lg md:text-xl font-bold mb-8 md:mb-12 max-w-xl border-l-4 md:border-l-8 border-black pl-4 md:pl-6 leading-snug">
              Plus besoin de CV interminables ou d'e-mails ignorés. Connecte-toi directement avec les meilleurs employeurs de Côte d'Ivoire.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 md:gap-6">
              <button className="neo-brutal-btn flex items-center justify-center gap-3 group w-full sm:w-auto">
                COMMENCER
                <ArrowRight size={24} className="group-hover:translate-x-1 transition-transform hidden sm:block" />
              </button>
              <button 
                onClick={() => setIsVideoModalOpen(true)}
                className="neo-brutal-btn-secondary flex items-center justify-center gap-3 w-full sm:w-auto"
              >
                <PlayCircle size={24} />
                DÉMO VIDEO
              </button>
            </div>

            <div className="mt-12 md:mt-16 grid grid-cols-3 min-[450px]:flex min-[450px]:flex-wrap items-center gap-y-8 gap-x-4 sm:gap-6 md:gap-8 justify-center lg:justify-start">
              <div className="text-center shrink-0 border-r-2 border-black/10 min-[450px]:border-none pr-4 min-[450px]:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">10K+</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Matchs</div>
              </div>
              <div className="text-center shrink-0 border-x-2 border-black/10 min-[450px]:border-none px-4 min-[450px]:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">24H</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Délai Moyen</div>
              </div>
              <div className="text-center shrink-0 border-l-2 border-black/10 min-[450px]:border-none pl-4 min-[450px]:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">98%</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Satisfaction</div>
              </div>
            </div>
          </div>
          
          <div className="relative">
            <div className="flex justify-center items-center">
              <AppSimulator />
            </div>
            
            {/* Floating Tags - Keep them for extra flair */}
            <div className="absolute -top-12 -right-4 neo-brutal-tag px-6 py-3 text-lg bg-green-400 rotate-12 shadow-xl z-20 hidden sm:block">
               HIRING! 💼
            </div>
            <div className="absolute top-1/2 -left-12 neo-brutal-tag px-6 py-3 text-lg bg-red-400 -rotate-12 shadow-xl z-20 hidden md:block">
               MATCH! 🔥
            </div>
          </div>

        </div>
      </section>

      {/* Features - How it works */}
      <section id="features" className="py-20 md:py-32 bg-white border-y-4 border-black px-4 md:px-6">
        <div className="max-w-7xl mx-auto">
          <div className="mb-12 md:mb-20 text-center">
            <span className="text-secondary font-black uppercase tracking-widest text-xs md:text-sm mb-2 md:mb-4 block">LE PROCESSUS</span>
            <h2 className="text-3xl min-[400px]:text-4xl md:text-5xl lg:text-7xl mb-6 text-black leading-tight">MÉTHODE <br/> <span className="text-primary italic uppercase">Brobrosseur</span></h2>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8">
            <FeatureCard 
              icon={<Smartphone className="text-black" size={32} />} 
              title="SWIPE À DROITE" 
              description="Parcoure les offres d'Abidjan et au-delà. Si ça te plaît, swipe à droite. C'est tout."
              colorClass="!bg-primary !text-white"
            />
            <FeatureCard 
              icon={<MessageSquare className="text-black" size={32} />} 
              title="MATCH & CHAT" 
              description="Si l'employeur te valide aussi, c'est un match ! Discutez directement sans intermédiaire."
              colorClass="!bg-white !text-black"
            />
            <FeatureCard 
              icon={<Briefcase className="text-black" size={32} />} 
              title="TROUVE TON JOB FACILEMENT" 
              description="Offres vérifiées et mise en relation directe ultra-rapide pour booster ta carrière."
              colorClass="!bg-secondary !text-white"
            />

          </div>
        </div>
      </section>


      {/* Premium Section - Comparison */}
      <section id="premium" className="py-20 md:py-32 bg-accent px-4 md:px-6 border-b-4 border-black overflow-hidden">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-12 md:mb-20">
            <h2 className="text-4xl sm:text-5xl md:text-7xl mb-4 md:mb-6 leading-none">NE RESTE <br/> PAS BLOQUÉ.</h2>
            <p className="text-lg md:text-xl font-bold max-w-2xl mx-auto px-4">
              Le "djorssi" n'attend pas. Choisis ton niveau et multiplie tes chances de décrocher ton prochain contrat.
            </p>
          </div>

          <div className="grid lg:grid-cols-2 gap-12 items-start">
            {/* Comparison Table */}
            <div className="neo-brutal-card !p-0 overflow-hidden !bg-white">
              <div className="bg-black text-white p-6">
                <h3 className="text-2xl font-black uppercase tracking-widest">COMPARATIF</h3>
              </div>
              <div className="divide-y-2 divide-black">
                {/* Header */}
                <div className="grid grid-cols-3 bg-slate-100 font-black text-[9px] min-[400px]:text-[10px] sm:text-xs uppercase tracking-tighter border-b-2 border-black">
                  <div className="p-2 sm:p-4 border-r-2 border-black flex items-center">OPTIONS</div>
                  <div className="p-2 sm:p-4 border-r-2 border-black text-center flex items-center justify-center">FREE</div>
                  <div className={`p-2 sm:p-4 text-center flex items-center justify-center bg-primary/10 text-primary`}>PREMIUM</div>
                </div>
                
                {/* Rows */}
                <ComparisonRow label="Swipes quotidiens" free="10 / Jour" premium="Illimités" isPremium />
                <ComparisonRow label="Candidature Directe" free={<CheckCircle size={18} />} premium={<CheckCircle size={18} />} />
                <ComparisonRow label="Voir qui t'a swipé" free={<X size={18} className="text-red-500" />} premium={<CheckCircle size={18} />} isPremium />
                <ComparisonRow label="Boost de profil" free={<X size={18} className="text-red-500" />} premium="2 / Semaine" isPremium />
                <ComparisonRow label="Badge Vérifié" free={<X size={18} className="text-red-500" />} premium={<CheckCircle size={18} />} isPremium />
                <ComparisonRow label="Support Prioritaire" free={<X size={18} className="text-red-500" />} premium={<CheckCircle size={18} />} isPremium />
              </div>
            </div>

            {/* Premium CTA Card */}
            <div className="flex flex-col gap-6 md:gap-8 min-w-0">
              <div className="neo-brutal-card !bg-white">
                <div className="flex flex-col sm:flex-row justify-between items-start mb-6 md:mb-8 gap-4">
                   <div className="min-w-0 overflow-hidden break-words">
                    <h3 className="text-3xl md:text-4xl text-black leading-none break-words">PASS <br/> <span className="text-primary italic">PREMIUM</span></h3>
                    <p className="text-3xl min-[400px]:text-4xl sm:text-5xl md:text-6xl font-black mt-4">2.000 <span className="text-xs sm:text-sm">FCFA / mois</span></p>
                   </div>
                   <div className="neo-brutal-tag bg-primary text-white scale-125 origin-top-left sm:origin-left hidden sm:block">LE TOP</div>
                </div>
                <p className="font-bold mb-8 text-slate-600">
                  L'investissement le plus rentable pour ta carrière. Débloque toutes les barrières dès aujourd'hui.
                </p>
                <button className="neo-brutal-btn w-full !bg-black !text-white text-2xl py-6">PASSER AU PREMIUM</button>
              </div>

              <div className="p-6 md:p-8 border-4 border-dashed border-black rounded-lg bg-white/50 relative mt-4">
                <div className="absolute -top-4 -right-2 md:-right-4 w-10 md:w-12 h-10 md:h-12 bg-accent border-2 border-black rounded-full flex items-center justify-center -rotate-12 shadow-md">
                  <span className="font-black text-xl md:text-2xl">"</span>
                </div>
                <span className="font-black italic text-lg md:text-2xl leading-snug">"Depuis que j'ai pris le premium, j'ai eu 5 entretiens en une semaine ! Ça vaut vraiment le coup."</span>
                <p className="mt-4 font-bold border-t-2 border-black/10 pt-4 text-sm md:text-base">— Moussa, Développeur PHP</p>
              </div>
            </div>
          </div>
        </div>
      </section>


      {/* CTA Final */}
      <section className="py-16 md:py-24 px-4 md:px-6 text-center">
        <div className="max-w-4xl mx-auto">
           <h2 className="text-5xl md:text-6xl lg:text-8xl mb-8 md:mb-12 leading-none uppercase italic">PRÊT À <br/> <span className="text-primary not-italic">BOSSER ?</span></h2>
           <button className="neo-brutal-btn text-lg md:text-2xl px-8 md:px-16 py-6 md:py-8 w-full sm:w-auto">TÉLÉCHARGER MAINTENANT</button>
           <p className="mt-6 md:mt-8 font-black uppercase text-xs md:text-sm tracking-widest opacity-50">Disponible sur iOS & Android</p>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-black text-white py-20 px-6">
        <div className="max-w-7xl mx-auto grid md:grid-cols-4 gap-12">
          <div className="col-span-2">
            <div className="flex items-center gap-3 mb-8">
              <div className="h-10 flex items-center justify-center">
                <img src="/logo.png" alt="Djorssi-Match Logo" className="h-full w-auto object-contain" />
              </div>
              <span className="font-heading text-xl font-black uppercase tracking-tighter">DJORSSI-MATCH</span>
            </div>
            <p className="font-medium text-slate-400 max-w-sm mb-8">
              La plateforme n°1 de mise en relation directe pour l'emploi en Côte d'Ivoire.
            </p>
            <div className="flex gap-4">
               {/* Social placeholders */}
               <div className="w-10 h-10 border-2 border-white bg-white/10 flex items-center justify-center hover:bg-primary transition-colors cursor-pointer">
                  <Globe size={20} />
               </div>
               <div className="w-10 h-10 border-2 border-white bg-white/10 flex items-center justify-center hover:bg-primary transition-colors cursor-pointer">
                  <span className="font-black">FB</span>
               </div>
               <div className="w-10 h-10 border-2 border-white bg-white/10 flex items-center justify-center hover:bg-primary transition-colors cursor-pointer">
                  <span className="font-black">IN</span>
               </div>
            </div>
          </div>
          <div>
            <h4 className="text-lg mb-6 uppercase">Legal</h4>
            <ul className="space-y-4 font-bold text-slate-400 text-sm">
              <li><Link to="/privacy" className="hover:text-white transition-colors">Confidentialité</Link></li>
              <li><Link to="/terms" className="hover:text-white transition-colors">CGU</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="text-lg mb-6 uppercase">Contact</h4>
            <ul className="space-y-4 font-bold text-slate-400 text-sm">
              <li>contact@djorssi-match.com</li>
              <li>Abidjan, Côte d'Ivoire</li>
              <li>+225 07 08 17 25 31</li>
            </ul>
          </div>
        </div>
        <div className="max-w-7xl mx-auto mt-20 pt-8 border-t border-white/10 text-center text-slate-600 font-bold text-sm">
           © 2026 DJORSSI-MATCH.
        </div>
      </footer>

      {/* Video Modal */}
      <AnimatePresence>
        {isVideoModalOpen && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsVideoModalOpen(false)}
              className="absolute inset-0 bg-black/80 backdrop-blur-sm"
            />
            <motion.div
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              className="relative w-full max-w-sm bg-black border-4 border-black shadow-[12px_12px_0px_0px_rgba(0,0,0,1)] rounded-3xl overflow-hidden z-10"
            >
              <button 
                onClick={() => setIsVideoModalOpen(false)}
                className="absolute top-6 right-6 z-50 p-2 bg-black/50 backdrop-blur-md hover:bg-black/70 transition-all border-2 border-white/50 text-white rounded-full animate-pulse"
              >
                <X size={20} strokeWidth={4} />
              </button>
              <div className="aspect-[9/19] relative">
                <video 
                  src="/demo.mp4" 
                  className="w-full h-full object-cover" 
                  controls 
                  autoPlay
                  playsInline
                />
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default LandingPage;

