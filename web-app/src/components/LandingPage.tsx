import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Download, MessageSquare, PlayCircle, X, Menu, Heart, Zap, Quote, Briefcase } from 'lucide-react';
import AppSimulator from './AppSimulator';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch';
const APP_STORE_URL = 'https://apps.apple.com/us/app/djorssi-match/id6767549287';

/** Détecte la plateforme de l'utilisateur et retourne l'URL du store correspondant */
const getSmartDownloadUrl = (): string => {
  const ua = navigator.userAgent || '';
  // iOS : iPhone, iPad, iPod (inclut iPadOS qui se présente parfois comme Mac)
  if (/iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) {
    return APP_STORE_URL;
  }
  // Android
  if (/Android/i.test(ua)) {
    return PLAY_STORE_URL;
  }
  // Desktop/autre : Play Store par défaut
  return PLAY_STORE_URL;
};

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



interface TestimonialProps {
  quote: string;
  name: string;
  role: string;
}

const TestimonialCard: React.FC<TestimonialProps> = ({ quote, name, role }) => (
  <div className="p-6 md:p-8 border-4 border-dashed border-black rounded-lg bg-white/50 relative">
    <div className="absolute -top-4 -right-2 md:-right-4 w-10 md:w-12 h-10 md:h-12 bg-black border-2 border-black rounded-full flex items-center justify-center -rotate-12 shadow-md">
      <Quote className="text-primary" size={20} />
    </div>
    <span className="font-black italic text-base md:text-lg leading-snug block">"{quote}"</span>
    <p className="mt-4 font-bold border-t-2 border-black/10 pt-4 text-sm md:text-base">— {name}, {role}</p>
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
              Djorssi<span className="text-primary hidden sm:inline">-Match</span>
            </span>
          </div>

          <div className="hidden md:flex items-center gap-6 font-black uppercase text-sm">
            <a href="#features" className="hover:text-primary transition-colors cursor-pointer">Comment ça marche</a>
            <a href="#deposer-offre" className="hover:text-primary transition-colors cursor-pointer">Recruter</a>
            <a href="#temoignages" className="hover:text-primary transition-colors cursor-pointer">Témoignages</a>
            <a
              href={getSmartDownloadUrl()}
              target="_blank"
              rel="noopener noreferrer"
              className="neo-brutal-btn py-2 px-6 text-sm flex items-center gap-2"
            >
              <Download size={16} />
              Télécharger l'app
            </a>
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
            <a href="#features" onClick={() => setIsMobileMenuOpen(false)} className="p-4 hover:bg-slate-100 transition-colors">Comment ça marche</a>
            <a href="#deposer-offre" onClick={() => setIsMobileMenuOpen(false)} className="p-4 hover:bg-slate-100 transition-colors">Recruter</a>
            <a href="#temoignages" onClick={() => setIsMobileMenuOpen(false)} className="p-4 hover:bg-slate-100 transition-colors">Témoignages</a>
            <div className="p-4 bg-slate-50">
               <a
                 href={getSmartDownloadUrl()}
                 target="_blank"
                 rel="noopener noreferrer"
                 className="neo-brutal-btn w-full py-3 text-sm flex items-center justify-center gap-2"
               >
                 <Download size={16} />
                 Télécharger l'app
               </a>
            </div>
          </div>
        )}
      </nav>

      {/* Hero Section */}
      <section className="relative pt-32 md:pt-40 pb-24 md:pb-32 px-4 md:px-6 overflow-hidden">
        <div className="absolute inset-0 bg-pattern"></div>
        <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 md:gap-16 items-center relative z-10 lg:pl-4">
          <div className="text-left mt-8 md:mt-0">
            <div className="inline-block neo-brutal-tag mb-6 md:mb-8 text-[10px] min-[400px]:text-xs sm:text-sm tracking-tight min-[400px]:tracking-widest leading-relaxed max-w-full whitespace-normal sm:whitespace-nowrap px-4 py-2 uppercase">
              +10 000 MATCHS RÉUSSIS EN CÔTE D'IVOIRE
            </div>
            <h1 className="text-4xl min-[400px]:text-5xl md:text-7xl lg:text-8xl mb-6 md:mb-8 leading-[0.9] text-black italic">
              TON PROCHAIN <span className="text-primary not-italic">Djorssi</span> EST À UN SWIPE.
            </h1>
            <p className="text-lg md:text-xl font-bold mb-8 md:mb-12 max-w-xl border-l-4 md:border-l-8 border-primary pl-4 md:pl-6 leading-snug">
              Swipe, matche, et le recruteur te contacte <strong>direct sur WhatsApp</strong>. Ton CV est envoyé automatiquement. C'est aussi simple que ça.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 md:gap-6">
              <a
                href={getSmartDownloadUrl()}
                target="_blank"
                rel="noopener noreferrer"
                className="neo-brutal-btn flex items-center justify-center gap-3 group w-full sm:w-auto no-underline !text-lg py-4"
              >
                <Download size={24} />
                TÉLÉCHARGER
              </a>
              <button 
                onClick={() => setIsVideoModalOpen(true)}
                className="neo-brutal-btn-secondary flex items-center justify-center gap-3 w-full sm:w-auto !text-lg py-4"
              >
                <PlayCircle size={24} />
                VOIR LA DÉMO
              </button>
            </div>

            <div className="mt-8 flex flex-col min-[450px]:flex-row items-stretch min-[450px]:items-center gap-4">
              {/* Google Play */}
              <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className="flex items-center justify-center min-[450px]:justify-start gap-3 bg-black text-white px-5 py-3 rounded-md border-2 border-black hover:scale-105 transition-transform no-underline shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.199l2.302 2.302a1 1 0 0 1 0 1.38l-2.302 2.302L15.396 13l2.302-2.492zM5.864 2.658L16.8 8.99l-2.302 2.302L5.864 2.658z"/></svg>
                <div className="text-left">
                  <div className="text-[10px] font-medium opacity-80 uppercase tracking-wider">Disponible sur</div>
                  <div className="text-sm font-black leading-tight">Google Play</div>
                </div>
              </a>
              
              {/* App Store */}
              <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" className="flex items-center justify-center min-[450px]:justify-start gap-3 bg-black text-white px-5 py-3 rounded-md border-2 border-black hover:scale-105 transition-transform no-underline shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
                <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.35-1.32-3.19-2.54-1.71-2.47-3.02-6.98-1.25-10.05.88-1.53 2.45-2.49 4.14-2.52 1.29-.02 2.5.87 3.29.87.79 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.31 2.81M15.96 3.54c.7-1 1.3-2.1 1.1-3.3-1 .1-2.3.8-3 1.8-.6.8-1.1 1.9-1 3 1 .1 2.2-.6 2.9-1.5z"/></svg>
                <div className="text-left">
                  <div className="text-[10px] font-medium opacity-80 uppercase tracking-wider">Disponible sur</div>
                  <div className="text-sm font-black leading-tight">App Store</div>
                </div>
              </a>
            </div>

            <div className="mt-10 md:mt-14 flex flex-wrap items-center gap-y-8 gap-x-4 sm:gap-6 md:gap-8 justify-center lg:justify-start">
              <div className="text-center min-w-[80px] sm:min-w-0 border-r-2 border-black/10 sm:border-none pr-4 sm:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">10K+</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Matchs réussis</div>
              </div>
              <div className="text-center min-w-[80px] sm:min-w-0 border-r-2 border-black/10 sm:border-none px-4 sm:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">24H</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Réponse moyenne</div>
              </div>
              <div className="text-center min-w-[80px] sm:min-w-0 pl-4 sm:p-0">
                <div className="text-2xl min-[400px]:text-3xl md:text-4xl font-black italic">500+</div>
                <div className="text-[10px] sm:text-xs md:text-sm font-black uppercase text-slate-500 tracking-tighter">Offres actives</div>
              </div>
            </div>
          </div>
          
          <div className="relative">
            <div className="flex justify-center items-center">
              <AppSimulator />
            </div>
            
            {/* Floating Tags - French */}
            <div className="absolute -top-12 -right-4 neo-brutal-tag px-6 py-3 text-lg bg-green-400 rotate-12 shadow-xl z-20 hidden sm:block">
               ON RECRUTE ! 💼
            </div>
            <div className="absolute top-1/2 -left-12 neo-brutal-tag px-6 py-3 text-lg bg-red-400 -rotate-12 shadow-xl z-20 hidden md:block">
               MATCH ! 🔥
            </div>
          </div>

        </div>
      </section>

      {/* Features - How it works */}
      <section id="features" className="py-20 md:py-32 bg-white border-y-4 border-black px-4 md:px-6">
        <div className="max-w-7xl mx-auto">
          <div className="mb-12 md:mb-20 text-center">
            <span className="text-secondary font-black uppercase tracking-widest text-xs md:text-sm mb-2 md:mb-4 block">COMMENT ÇA MARCHE</span>
            <h2 className="text-3xl min-[400px]:text-4xl md:text-5xl lg:text-7xl mb-6 text-black leading-tight">3 ÉTAPES POUR <br/> <span className="text-primary italic uppercase">TON JOB</span></h2>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8">
            <FeatureCard 
              icon={<Heart className="text-black" size={32} />} 
              title="1. SWIPE À DROITE" 
              description="Parcours les offres d'Abidjan et au-delà. Une offre te plaît ? Swipe à droite. Ton CV part automatiquement."
              colorClass="!bg-primary !text-white"
            />
            <FeatureCard 
              icon={<Zap className="text-black" size={32} />} 
              title="2. C'EST UN MATCH !" 
              description="Le recruteur reçoit ton CV instantanément. S'il valide ton profil, tu reçois une notification direct."
              colorClass="!bg-white !text-black"
            />
            <FeatureCard 
              icon={<MessageSquare className="text-black" size={32} />} 
              title="3. CONTACT WHATSAPP" 
              description="Discute directement avec le recruteur sur WhatsApp. Pas d'intermédiaire, pas d'attente. Tu bosses."
              colorClass="!bg-secondary !text-white"
            />
          </div>

          {/* Mid-page CTA */}
          <div className="mt-16 text-center">
            <a
              href={getSmartDownloadUrl()}
              target="_blank"
              rel="noopener noreferrer"
              className="neo-brutal-btn inline-flex items-center gap-3 text-lg no-underline"
            >
              <Download size={22} />
              Télécharger l'app
            </a>
          </div>
        </div>
      </section>

      {/* Recruiter space call-to-action banner */}
      <section id="deposer-offre" className="py-20 md:py-32 bg-[#FEF08A] border-b-4 border-black px-4 md:px-6 relative">
        <div className="absolute inset-0 bg-pattern opacity-10"></div>
        <div className="max-w-4xl mx-auto relative z-10 text-center">
          <div className="border-4 border-black bg-white p-8 md:p-12 shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] rounded-2xl space-y-8">
            <div className="inline-block neo-brutal-tag !bg-secondary !text-white mb-2 text-sm uppercase">
              RECRUTEZ FACILEMENT
            </div>
            <h2 className="text-4xl md:text-5xl lg:text-7xl font-heading font-black uppercase leading-none">
              TROUVEZ VOS TALENTS <br/>
              <span className="text-[#10B981] not-italic">SUR DJORSSI-MATCH</span>
            </h2>
            <p className="font-bold text-slate-700 max-w-2xl mx-auto text-lg leading-relaxed">
              Publiez vos offres d'emploi sur notre plateforme dédiée et entrez en contact direct avec les candidats qualifiés d'Abidjan par WhatsApp et e-mail. Simple, rapide et sans intermédiaire.
            </p>
            
            <div className="grid md:grid-cols-3 gap-6 text-left max-w-3xl mx-auto pt-4">
              <div className="p-4 border-2 border-black rounded-xl bg-slate-50 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">
                <p className="font-black uppercase text-xs tracking-wider text-slate-400 mb-1">ÉTAPE 1</p>
                <p className="font-black text-sm text-black mb-1">Renseignez le poste</p>
                <p className="text-xs font-bold text-slate-500">Ajoutez le titre, le lieu, le contrat (CDI, CDD, Stage...) et vos exigences.</p>
              </div>
              <div className="p-4 border-2 border-black rounded-xl bg-slate-50 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">
                <p className="font-black uppercase text-xs tracking-wider text-slate-400 mb-1">ÉTAPE 2</p>
                <p className="font-black text-sm text-black mb-1">Ciblez les profils</p>
                <p className="text-xs font-bold text-slate-500">Sélectionnez les secteurs et compétences clés. Exigez ou non une lettre de motivation.</p>
              </div>
              <div className="p-4 border-2 border-black rounded-xl bg-slate-50 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">
                <p className="font-black uppercase text-xs tracking-wider text-slate-400 mb-1">ÉTAPE 3</p>
                <p className="font-black text-sm text-black mb-1">Matchez en direct</p>
                <p className="text-xs font-bold text-slate-500">Les candidats swipent votre offre. Entrez en contact direct avec eux sur WhatsApp.</p>
              </div>
            </div>

            <div className="pt-6">
              <Link
                to="/recruteur"
                className="neo-brutal-btn inline-flex items-center gap-3 text-xl font-black uppercase px-8 py-5 justify-center no-underline"
              >
                <Briefcase size={22} />
                Accéder à l'Espace Recruteurs
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section id="temoignages" className="py-20 md:py-32 px-4 md:px-6 bg-background">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-12 md:mb-20">
            <span className="text-primary font-black uppercase tracking-widest text-xs md:text-sm mb-2 md:mb-4 block">ILS ONT TROUVÉ LEUR DJORSSI</span>
            <h2 className="text-3xl min-[400px]:text-4xl md:text-5xl lg:text-7xl mb-6 text-black leading-tight">LA PREUVE <br/> <span className="text-secondary italic">PAR L'ACTION</span></h2>
          </div>

          <div className="grid md:grid-cols-3 gap-6 md:gap-8">
            <TestimonialCard
              quote="J'ai swipé le matin, l'après-midi le recruteur m'appelait sur WhatsApp. En 48h j'avais mon contrat. Wallaye c'est magique !"
              name="Awa"
              role="Caissière, Cocody"
            />
            <TestimonialCard
              quote="Depuis que j'ai pris le premium, j'ai eu 5 entretiens en une semaine ! Ça vaut vraiment le coup."
              name="Moussa"
              role="Développeur PHP"
            />
            <TestimonialCard
              quote="Avant je déposais mes CV partout sans réponse. Avec Djorssi Match, c'est le recruteur qui vient vers toi. Le game a changé."
              name="Ibrahim"
              role="Comptable, Plateau"
            />
          </div>
        </div>
      </section>

      {/* CTA Final — Dream Section */}
      <section className="py-20 md:py-32 px-4 md:px-6 bg-black text-white border-y-4 border-black overflow-hidden relative">
        <div className="absolute inset-0 opacity-5">
          <div className="bg-pattern" style={{filter: 'invert(1)'}}></div>
        </div>
        <div className="max-w-4xl mx-auto text-center relative z-10">
          <div className="inline-block neo-brutal-tag !bg-primary !text-white !border-white mb-8 text-sm tracking-widest">
            GRATUIT • RAPIDE • DIRECT
          </div>
          <h2 className="text-5xl md:text-6xl lg:text-8xl mb-6 md:mb-8 leading-none uppercase italic text-white">
            TON JOB T'ATTEND.<br/>
            <span className="text-primary not-italic">SWIPE.</span>
          </h2>
          <p className="text-lg md:text-xl font-bold mb-10 md:mb-14 max-w-2xl mx-auto text-slate-300 leading-relaxed">
            Rejoins les <strong className="text-white">milliers d'Ivoiriens</strong> qui ont trouvé leur emploi grâce à Djorssi Match. Télécharge l'app, crée ton profil en 2 minutes, et commence à swiper.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 md:gap-6 justify-center items-center">
            <a
              href={getSmartDownloadUrl()}
              target="_blank"
              rel="noopener noreferrer"
              className="neo-brutal-btn !bg-primary !border-white text-2xl px-10 md:px-16 py-6 md:py-8 w-full sm:w-auto flex items-center justify-center gap-4 no-underline group"
            >
              <Download size={28} />
              Télécharger l'app
            </a>
          </div>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer" className="flex items-center gap-3 bg-white/10 backdrop-blur text-white px-5 py-3 rounded-md border border-white/30 hover:bg-white/20 transition-all no-underline shadow-[4px_4px_0px_0px_rgba(0,0,0,0.3)]">
              <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.199l2.302 2.302a1 1 0 0 1 0 1.38l-2.302 2.302L15.396 13l2.302-2.492zM5.864 2.658L16.8 8.99l-2.302 2.302L5.864 2.658z"/></svg>
              <span className="font-black text-sm">Google Play</span>
            </a>
            
            <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" className="flex items-center gap-3 bg-white/10 backdrop-blur text-white px-5 py-3 rounded-md border border-white/30 hover:bg-white/20 transition-all no-underline shadow-[4px_4px_0px_0px_rgba(0,0,0,0.3)]">
              <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.35-1.32-3.19-2.54-1.71-2.47-3.02-6.98-1.25-10.05.88-1.53 2.45-2.49 4.14-2.52 1.29-.02 2.5.87 3.29.87.79 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.31 2.81M15.96 3.54c.7-1 1.3-2.1 1.1-3.3-1 .1-2.3.8-3 1.8-.6.8-1.1 1.9-1 3 1 .1 2.2-.6 2.9-1.5z"/></svg>
              <span className="font-black text-sm">App Store</span>
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-black text-white py-20 px-6 border-t-4 border-primary">
        <div className="max-w-7xl mx-auto grid md:grid-cols-4 gap-12">
          <div className="col-span-2">
            <div className="flex items-center gap-3 mb-8">
              <div className="h-10 flex items-center justify-center">
                <img src="/logo.png" alt="Djorssi-Match Logo" className="h-full w-auto object-contain" />
              </div>
              <span className="font-heading text-xl font-black uppercase tracking-tighter">Djorssi-Match</span>
            </div>
            <p className="font-medium text-slate-400 max-w-sm mb-8">
              La plateforme n°1 de mise en relation directe pour l'emploi en Côte d'Ivoire. Swipe, matche, bosse.
            </p>
            <div className="flex flex-wrap gap-3">
              <a
                href={PLAY_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 bg-primary text-white px-5 py-3 rounded-lg font-black text-sm border-2 border-white/20 hover:scale-105 transition-transform no-underline"
              >
                <Download size={16} />
                Google Play
              </a>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 bg-white text-black px-5 py-3 rounded-lg font-black text-sm border-2 border-white/20 hover:scale-105 transition-transform no-underline"
              >
                <Download size={16} />
                App Store
              </a>
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
           © 2026 Djorssi-Match. Tous droits réservés.
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
