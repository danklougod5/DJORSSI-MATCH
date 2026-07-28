import React, { useState, useEffect } from 'react';
import { Building2, Search, Star, UserX, UserCheck, Trash2, Pencil, RefreshCw, Briefcase } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface CompanyProfile {
  id: string;
  full_name: string;
  company_name: string;
  company_industry: string;
  company_size: string;
  phone_number: string;
  is_premium: boolean;
  premium_until?: string | null;
  is_blocked: boolean;
  created_at: string;
  job_count?: number;
}

interface CompaniesTabProps {
  onTogglePremium: (userId: string, currentPremium: boolean) => Promise<void>;
  onToggleBlockUser: (userId: string, currentBlocked: boolean) => Promise<void>;
  onDeleteProfile: (userId: string) => Promise<void>;
  onEditUser: (user: any) => void;
}

const CompaniesTab: React.FC<CompaniesTabProps> = ({
  onTogglePremium,
  onToggleBlockUser,
  onDeleteProfile,
  onEditUser,
}) => {
  const [companies, setCompanies] = useState<CompanyProfile[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'premium' | 'blocked'>('all');
  const [sectorFilter, setSectorFilter] = useState<string>('all');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);

  useEffect(() => {
    fetchCompanies();
  }, []);

  const fetchCompanies = async () => {
    setIsLoading(true);
    try {
      // 1. Fetch profiles where is_recruiter is true
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('is_recruiter', true)
        .order('created_at', { ascending: false });

      if (error) throw error;

      // 2. Fetch job counts per recruiter
      const { data: jobData } = await supabase
        .from('jobs')
        .select('recruiter_id');

      const jobCountMap = new Map<string, number>();
      (jobData || []).forEach((j: any) => {
        if (j.recruiter_id) {
          jobCountMap.set(j.recruiter_id, (jobCountMap.get(j.recruiter_id) || 0) + 1);
        }
      });

      const formatted: CompanyProfile[] = (data || []).map((c: any) => ({
        id: c.id,
        full_name: c.full_name || 'Contact Inconnu',
        company_name: c.company_name || c.full_name || 'Entreprise Sans Nom',
        company_industry: c.company_industry || 'Non spécifié',
        company_size: c.company_size || '-',
        phone_number: c.phone_number || '-',
        is_premium: c.is_premium === true,
        premium_until: c.premium_until,
        is_blocked: c.is_blocked === true,
        created_at: c.created_at ? new Date(c.created_at).toLocaleDateString('fr-FR') : '-',
        job_count: jobCountMap.get(c.id) || 0,
      }));

      setCompanies(formatted);
    } catch (err) {
      console.error('Error fetching companies:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleBlockToggle = async (company: CompanyProfile) => {
    setActionLoadingId(company.id);
    try {
      await onToggleBlockUser(company.id, company.is_blocked);
      setCompanies(prev =>
        prev.map(c => (c.id === company.id ? { ...c, is_blocked: !company.is_blocked } : c))
      );
    } catch (err) {
      console.error('Error toggling block:', err);
    } finally {
      setActionLoadingId(null);
    }
  };

  const handlePremiumToggle = async (company: CompanyProfile) => {
    setActionLoadingId(company.id);
    try {
      await onTogglePremium(company.id, company.is_premium);
      setCompanies(prev =>
        prev.map(c => (c.id === company.id ? { ...c, is_premium: !company.is_premium } : c))
      );
    } catch (err) {
      console.error('Error toggling premium:', err);
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDelete = async (company: CompanyProfile) => {
    if (window.confirm(`Voulez-vous vraiment supprimer l'entreprise "${company.company_name}" ?`)) {
      setActionLoadingId(company.id);
      try {
        await onDeleteProfile(company.id);
        setCompanies(prev => prev.filter(c => c.id !== company.id));
      } catch (err) {
        console.error('Error deleting company:', err);
      } finally {
        setActionLoadingId(null);
      }
    }
  };

  const filteredCompanies = companies.filter(c => {
    const q = searchTerm.toLowerCase();
    const matchesSearch =
      c.company_name.toLowerCase().includes(q) ||
      c.full_name.toLowerCase().includes(q) ||
      c.company_industry.toLowerCase().includes(q) ||
      c.phone_number.includes(q);

    let matchesStatus = true;
    if (statusFilter === 'premium') matchesStatus = c.is_premium;
    if (statusFilter === 'blocked') matchesStatus = c.is_blocked;

    let matchesSector = true;
    if (sectorFilter !== 'all') matchesSector = c.company_industry.toLowerCase() === sectorFilter.toLowerCase();

    return matchesSearch && matchesStatus && matchesSector;
  });

  const uniqueSectors = Array.from(
    new Set(companies.map(c => c.company_industry).filter(Boolean))
  );

  const totalCompanies = companies.length;
  const premiumCompanies = companies.filter(c => c.is_premium).length;
  const blockedCompanies = companies.filter(c => c.is_blocked).length;

  return (
    <div className="space-y-6">
      {/* Top Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Total Entreprises</p>
            <h4 className="text-2xl font-black text-slate-900 mt-1">{totalCompanies}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
            <Building2 size={24} />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Entreprises Premium</p>
            <h4 className="text-2xl font-black text-amber-500 mt-1">{premiumCompanies}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-500 flex items-center justify-center">
            <Star size={24} fill="currentColor" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Entreprises Suspendues</p>
            <h4 className="text-2xl font-black text-red-500 mt-1">{blockedCompanies}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-red-50 text-red-500 flex items-center justify-center">
            <UserX size={24} />
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-6">
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4">
          <div>
            <h3 className="text-xl font-bold text-slate-900 flex items-center gap-2">
              <Building2 className="text-primary" size={22} />
              Répertoire des Entreprises Recruteuses
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Gérez les comptes entreprises, attribuez le statut Premium ou bloquez les profils suspects.
            </p>
          </div>

          <button
            onClick={fetchCompanies}
            disabled={isLoading}
            className="flex items-center gap-2 px-3.5 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all"
          >
            <RefreshCw size={14} className={isLoading ? 'animate-spin' : ''} />
            Rafraîchir
          </button>
        </div>

        {/* Filters & Search */}
        <div className="flex flex-col md:flex-row gap-4 justify-between items-center">
          <div className="relative w-full md:w-80">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input
              type="text"
              placeholder="Rechercher entreprise, contact, secteur..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:border-primary focus:bg-white transition-all"
            />
          </div>

          <div className="flex flex-wrap items-center gap-3 w-full md:w-auto">
            {/* Status Filter */}
            <div className="flex bg-slate-100 p-1 rounded-xl text-xs font-bold">
              <button
                onClick={() => setStatusFilter('all')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  statusFilter === 'all' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                Toutes
              </button>
              <button
                onClick={() => setStatusFilter('premium')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  statusFilter === 'premium' ? 'bg-amber-500 text-white shadow-sm' : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                Premium ⭐️
              </button>
              <button
                onClick={() => setStatusFilter('blocked')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  statusFilter === 'blocked' ? 'bg-red-500 text-white shadow-sm' : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                Suspendues 🔴
              </button>
            </div>

            {/* Sector Dropdown */}
            {uniqueSectors.length > 0 && (
              <select
                value={sectorFilter}
                onChange={e => setSectorFilter(e.target.value)}
                className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-xs font-medium text-slate-700 focus:outline-none focus:border-primary"
              >
                <option value="all">Tous les secteurs</option>
                {uniqueSectors.map(s => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            )}
          </div>
        </div>

        {/* Table */}
        {isLoading ? (
          <div className="py-20 text-center text-slate-400 flex flex-col items-center gap-3">
            <RefreshCw className="animate-spin text-primary" size={32} />
            <p className="font-bold text-sm">Chargement du répertoire des entreprises...</p>
          </div>
        ) : filteredCompanies.length === 0 ? (
          <div className="py-16 text-center text-slate-400 bg-slate-50 rounded-2xl border border-dashed border-slate-200">
            <Building2 size={36} className="mx-auto mb-2 opacity-50" />
            <p className="font-bold text-sm text-slate-600">Aucune entreprise trouvée.</p>
            <p className="text-xs text-slate-400 mt-1">Essayez de modifier votre recherche ou vos filtres.</p>
          </div>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-slate-200">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 text-slate-500 font-bold uppercase tracking-wider">
                  <th className="py-3.5 px-4">Entreprise & Contact</th>
                  <th className="py-3.5 px-4">Secteur</th>
                  <th className="py-3.5 px-4">Téléphone</th>
                  <th className="py-3.5 px-4">Offres Publiées</th>
                  <th className="py-3.5 px-4">Inscrit le</th>
                  <th className="py-3.5 px-4">Statut</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredCompanies.map(company => (
                  <tr
                    key={company.id}
                    className={`hover:bg-slate-50/80 transition-colors ${
                      company.is_blocked ? 'bg-red-50/40' : ''
                    }`}
                  >
                    {/* Company Name & Contact */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-slate-900 text-white font-bold flex items-center justify-center text-sm shadow-sm">
                          {company.company_name.substring(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 text-sm leading-tight flex items-center gap-1.5">
                            {company.company_name}
                            {company.is_premium && (
                              <Star size={14} className="text-amber-500 fill-amber-500" />
                            )}
                          </p>
                          <p className="text-[11px] text-slate-500">Contact: {company.full_name}</p>
                        </div>
                      </div>
                    </td>

                    {/* Sector & Size */}
                    <td className="py-3.5 px-4">
                      <span className="px-2.5 py-1 rounded-md bg-slate-100 text-slate-700 font-bold text-[11px]">
                        {company.company_industry}
                      </span>
                    </td>

                    {/* Phone */}
                    <td className="py-3.5 px-4 font-semibold text-slate-700">
                      {company.phone_number}
                    </td>

                    {/* Job Count */}
                    <td className="py-3.5 px-4 font-bold text-slate-900">
                      <span className="px-2.5 py-1 rounded-lg bg-blue-50 text-blue-700 font-bold text-xs inline-flex items-center gap-1">
                        <Briefcase size={12} />
                        {company.job_count} offres
                      </span>
                    </td>

                    {/* Created Date */}
                    <td className="py-3.5 px-4 text-slate-500 font-medium">
                      {company.created_at}
                    </td>

                    {/* Status Badge */}
                    <td className="py-3.5 px-4">
                      {company.is_blocked ? (
                        <span className="px-2.5 py-1 rounded-full bg-red-100 text-red-700 font-bold text-[10px] uppercase tracking-wider inline-flex items-center gap-1">
                          <UserX size={12} /> Bloqué
                        </span>
                      ) : company.is_premium ? (
                        <span className="px-2.5 py-1 rounded-full bg-amber-100 text-amber-700 font-bold text-[10px] uppercase tracking-wider inline-flex items-center gap-1">
                          <Star size={12} fill="currentColor" /> Premium
                        </span>
                      ) : (
                        <span className="px-2.5 py-1 rounded-full bg-slate-100 text-slate-600 font-bold text-[10px] uppercase tracking-wider">
                          Gratuit
                        </span>
                      )}
                    </td>

                    {/* Actions */}
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {/* Premium Toggle */}
                        <button
                          onClick={() => handlePremiumToggle(company)}
                          disabled={actionLoadingId === company.id}
                          title={company.is_premium ? 'Rétrograder en Free' : 'Rendre Premium'}
                          className={`p-2 rounded-lg transition-colors ${
                            company.is_premium
                              ? 'bg-amber-100 text-amber-700 hover:bg-amber-200'
                              : 'bg-slate-100 text-slate-500 hover:bg-amber-50 hover:text-amber-600'
                          }`}
                        >
                          <Star size={14} fill={company.is_premium ? 'currentColor' : 'none'} />
                        </button>

                        {/* Block / Unblock Toggle */}
                        <button
                          onClick={() => handleBlockToggle(company)}
                          disabled={actionLoadingId === company.id}
                          title={company.is_blocked ? 'Débloquer l\'entreprise' : 'Bloquer l\'entreprise'}
                          className={`p-2 rounded-lg transition-colors ${
                            company.is_blocked
                              ? 'bg-green-100 text-green-700 hover:bg-green-200'
                              : 'bg-red-50 text-red-600 hover:bg-red-100'
                          }`}
                        >
                          {company.is_blocked ? <UserCheck size={14} /> : <UserX size={14} />}
                        </button>

                        {/* Edit */}
                        <button
                          onClick={() => onEditUser(company)}
                          title="Éditer le profil"
                          className="p-2 rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors"
                        >
                          <Pencil size={14} />
                        </button>

                        {/* Delete */}
                        <button
                          onClick={() => handleDelete(company)}
                          disabled={actionLoadingId === company.id}
                          title="Supprimer l'entreprise"
                          className="p-2 rounded-lg bg-slate-100 text-slate-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

export default CompaniesTab;
