import React from 'react';
import FeedbackCard from './FeedbackCard';

interface FeedbackTabProps {
  feedbacks: any[];
  unsubscriptions: any[];
}

const FeedbackTab: React.FC<FeedbackTabProps> = ({ feedbacks, unsubscriptions }) => {
  return (
    <div className="grid grid-cols-1 gap-6">
      <h3 className="text-xl mb-4 text-slate-900 font-bold">Raisons des Désabonnements</h3>
      <div className="grid md:grid-cols-2 gap-6">
         {unsubscriptions.length > 0 ? unsubscriptions.map((unsub, idx) => (
           <FeedbackCard 
             key={`unsub-${idx}`}
             type="unsub" 
             user={unsub.user} 
             date={unsub.date} 
             content={unsub.content} 
             reason={unsub.reason}
           />
         )) : (
           <p className="text-slate-400 italic col-span-2">Aucun désabonnement enregistré.</p>
         )}
      </div>
      
      <h3 className="text-xl mt-8 mb-4 text-slate-900 font-bold">Feedbacks Récents</h3>
      <div className="grid md:grid-cols-3 gap-6">
         {feedbacks.length > 0 ? feedbacks.map((fb, idx) => (
           <FeedbackCard 
             key={`fb-${idx}`}
             type="feedback" 
             user={fb.user} 
             date={fb.date} 
             content={fb.content} 
             rating={fb.rating}
           />
         )) : (
           <p className="text-slate-400 italic col-span-3">Aucun feedback enregistré.</p>
         )}
      </div>
    </div>
  );
};

export default FeedbackTab;
