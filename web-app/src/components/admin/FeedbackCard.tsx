import React from 'react';

interface FeedbackCardProps {
  type: 'unsub' | 'feedback';
  user: string;
  date: string;
  content: string;
  reason?: string;
  rating?: number;
}

const FeedbackCard: React.FC<FeedbackCardProps> = ({ type, user, date, content, reason, rating }) => (
  <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
    <div className="flex justify-between items-start mb-4">
       <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 text-xs font-bold">
            {user.charAt(0)}
          </div>
          <div>
            <p className="text-sm font-bold text-slate-900">{user}</p>
            <p className="text-xs text-slate-400">{date}</p>
          </div>
       </div>
       <span className={`text-[10px] font-bold px-2 py-0.5 rounded uppercase ${type === 'unsub' ? 'bg-red-50 text-red-500' : 'bg-secondary/10 text-secondary'}`}>
         {type === 'unsub' ? 'Désabonné' : 'Feedback'}
       </span>
    </div>
    <p className="text-sm text-slate-600 mb-4 italic">"{content}"</p>
    {reason && (
      <div className="flex items-center gap-2 text-xs font-semibold text-slate-500">
         <span className="bg-slate-100 px-2 py-1 rounded">Raison: {reason}</span>
      </div>
    )}
    {rating && (
       <div className="flex gap-1">
          {[1, 2, 3, 4, 5].map(i => (
             <div key={i} className={`w-2 h-2 rounded-full ${i <= rating ? 'bg-orange-400' : 'bg-slate-200'}`} />
          ))}
       </div>
    )}
  </div>
);

export default FeedbackCard;
