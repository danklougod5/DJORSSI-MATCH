import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart, X, MessageSquare, MapPin, Building2 } from 'lucide-react';


interface Job {
  id: number;
  title: string;
  company: string;
  location: string;
  type: string;
  image: string;
}

const DUMMY_JOBS: Job[] = [
  {
    id: 1,
    title: "Comptable Junior",
    company: "Cabinet Ivoire",
    location: "Cocody, Abidjan",
    type: "CDI",
    image: "https://images.unsplash.com/photo-1554224155-6726b3ff858f?q=80&w=400&h=600&auto=format&fit=crop"
  },
  {
    id: 2,
    title: "Vendeuse Boutique",
    company: "Fashion Hub",
    location: "Plateau, Abidjan",
    type: "CDD",
    image: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=400&h=600&auto=format&fit=crop"
  },
  {
    id: 3,
    title: "Livreur Moto",
    company: "Express Delivery",
    location: "Yopougon, Abidjan",
    type: "Freelance",
    image: "https://images.unsplash.com/photo-1558981806-ec527fa84c39?q=80&w=400&h=600&auto=format&fit=crop"
  },
  {
    id: 4,
    title: "Serveur (H/F)",
    company: "Maquis Le Baron",
    location: "Marcory, Abidjan",
    type: "CDI",
    image: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=400&h=600&auto=format&fit=crop"
  }
];

const AppSimulator: React.FC = () => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [lastAction, setLastAction] = useState<'match' | 'reject' | null>(null);
  const [showPopup, setShowPopup] = useState(false);

  const handleSwipe = (direction: 'left' | 'right') => {
    if (direction === 'right') {
      setLastAction('match');
      setShowPopup(true);
      setTimeout(() => setShowPopup(false), 3000);
    } else {
      setLastAction('reject');
    }
    
    setTimeout(() => {
      setCurrentIndex((prev) => (prev + 1) % DUMMY_JOBS.length);
      setLastAction(null);
    }, 300);
  };

  const currentJob = DUMMY_JOBS[currentIndex];

  return (
    <div className="relative w-full max-w-[360px] mx-auto h-[600px] flex flex-col gap-4 px-2">
      <div className="flex-1 relative perspective-1000">
        <AnimatePresence mode="popLayout">
          <motion.div
            key={currentJob.id}
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ 
              x: lastAction === 'match' ? 500 : lastAction === 'reject' ? -500 : 0,
              rotate: lastAction === 'match' ? 30 : lastAction === 'reject' ? -30 : 0,
              opacity: 0 
            }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="absolute inset-y-0 inset-x-2 bg-white border-[4px] border-black shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] rounded-3xl overflow-hidden flex flex-col"
          >
            {/* Image Section */}
            <div className="relative h-[65%] bg-slate-200">
              <img src={currentJob.image} alt={currentJob.title} className="w-full h-full object-cover" />
              <div className="absolute top-4 right-4 neo-brutal-tag bg-white shadow-sm">
                {currentJob.type}
              </div>
              
              {/* Swipe Indicater Overlays */}
              {lastAction === 'match' && (
                <div className="absolute inset-0 bg-secondary/40 flex items-center justify-center border-4 border-secondary">
                  <div className="bg-white border-4 border-black px-6 py-2 rotate-[-12deg] shadow-lg">
                    <span className="text-secondary font-black text-4xl uppercase">MATCH!</span>
                  </div>
                </div>
              )}
              {lastAction === 'reject' && (
                <div className="absolute inset-0 bg-red-400/40 flex items-center justify-center border-4 border-red-500">
                  <div className="bg-white border-4 border-black px-6 py-2 rotate-[12deg] shadow-lg">
                    <span className="text-red-500 font-black text-4xl uppercase">NON</span>
                  </div>
                </div>
              )}
            </div>

            {/* Info Section */}
            <div className="flex-1 p-6 flex flex-col justify-between">
              <div>
                <h4 className="text-2xl font-black italic tracking-tighter mb-2">{currentJob.title}</h4>
                <div className="space-y-1">
                  <div className="flex items-center gap-2 text-sm font-bold opacity-70">
                    <Building2 size={16} />
                    {currentJob.company}
                  </div>
                  <div className="flex items-center gap-2 text-sm font-bold opacity-70">
                    <MapPin size={16} />
                    {currentJob.location}
                  </div>
                </div>
              </div>
              
              <div className="flex items-center gap-2 mt-4">
                <div className="neo-brutal-tag !bg-accent !text-black border-none text-[10px]">RECOMMANDÉ</div>
                <div className="neo-brutal-tag !bg-black !text-white border-none text-[10px]">ABIDJAN</div>
              </div>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Control Buttons */}
      <div className="flex justify-between items-center px-12 pb-4">
        <button 
          onClick={() => handleSwipe('left')}
          className="w-16 h-16 rounded-full bg-white border-[3px] border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center justify-center text-red-500 transition-all active:translate-x-1 active:translate-y-1 active:shadow-none"
        >
          <X size={32} strokeWidth={4} />
        </button>
        <button 
          onClick={() => handleSwipe('right')}
          className="w-20 h-20 rounded-full bg-secondary border-[3px] border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center justify-center text-white transition-all active:translate-x-1 active:translate-y-1 active:shadow-none shadow-secondary/20"
        >
          <Heart size={40} strokeWidth={3} fill="currentColor" />
        </button>
      </div>

      {/* Success Popup */}
      <AnimatePresence>
        {showPopup && (
          <div className="absolute inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ y: 50, opacity: 0, scale: 0.8 }}
              animate={{ y: 0, opacity: 1, scale: 1 }}
              exit={{ y: 50, opacity: 0, scale: 0.8 }}
              className="w-full max-w-[320px]"
            >
              <div className="neo-brutal-card !bg-white text-center border-[4px] shadow-xl rotate-[-2deg] !p-6 sm:!p-8">
                <div className="w-16 h-16 bg-green-400 border-2 border-black rounded-full flex items-center justify-center mx-auto mb-4 scale-110">
                  <MessageSquare className="text-black" size={32} />
                </div>
                <h5 className="text-xl font-black mb-2 uppercase italic">MATCH PARFAIT !</h5>
                <p className="font-bold text-sm">Ton CV a été envoyé au recruteur.</p>
  
                <div className="mt-4 pt-4 border-t-2 border-black/10">
                  <span className="text-xs font-black text-secondary tracking-widest">PATIENTE 24H</span>
                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default AppSimulator;
