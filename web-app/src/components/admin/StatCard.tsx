import React from 'react';

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ReactElement;
  color: string;
  trend: string;
}

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, color, trend }) => (
  <div className="bg-white p-4 md:p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between hover:border-primary/30 transition-colors">
    <div className="flex justify-between items-start mb-4">
      <div className={`w-10 h-10 md:w-12 md:h-12 rounded-xl flex items-center justify-center text-white ${color} shadow-lg shadow-black/10`}>
        {React.cloneElement(icon as React.ReactElement<any>, { size: 20, className: "md:w-6 md:h-6" })}
      </div>
      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">Live Stats</span>
    </div>
    <div>
      <p className="text-slate-500 text-xs md:text-sm font-medium">{title}</p>
      <div className="flex items-baseline gap-2 flex-wrap">
         <h4 className="text-2xl md:text-3xl font-heading font-bold text-slate-900">{value}</h4>
         <span className="text-[10px] font-bold text-cta whitespace-nowrap">{trend}</span>
      </div>
    </div>
  </div>
);

export default StatCard;
