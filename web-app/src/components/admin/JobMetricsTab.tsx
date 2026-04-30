import React, { useState, useEffect, useMemo } from 'react';
import {
  Search,
  Tag,
  ChevronDown,
  ChevronUp,
  Briefcase,
  MapPin,
  Calendar,
  ArrowUpDown,
  RefreshCw,
  BarChart3,
  ExternalLink
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface JobMetricsTabProps {}

interface TagMetric {
  tag: string;
  count: number;
  jobs: any[];
}

const JobMetricsTab: React.FC<JobMetricsTabProps> = () => {
  const [allJobs, setAllJobs] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortBy, setSortBy] = useState<'count' | 'alpha'>('count');
  const [expandedTag, setExpandedTag] = useState<string | null>(null);

  // Fetch all jobs ONCE on mount
  useEffect(() => {
    fetchAllJobs();
  }, []);

  const fetchAllJobs = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('jobs')
        .select('id, job_title, company_name, location, deadline, tags, created_at, application_link, source_url')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAllJobs(data || []);
    } catch (err) {
      console.error('Error fetching jobs for metrics:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // Calculate tag metrics from jobs
  const tagMetrics: TagMetric[] = useMemo(() => {
    const tagMap: Record<string, any[]> = {};

    allJobs.forEach(job => {
      if (Array.isArray(job.tags)) {
        job.tags.forEach((tag: string) => {
          if (tag && tag.trim()) {
            const normalizedTag = tag.trim();
            if (!tagMap[normalizedTag]) tagMap[normalizedTag] = [];
            tagMap[normalizedTag].push(job);
          }
        });
      }
    });

    let metrics = Object.entries(tagMap).map(([tag, jobs]) => ({
      tag,
      count: jobs.length,
      jobs
    }));

    // Sort
    if (sortBy === 'count') {
      metrics.sort((a, b) => b.count - a.count);
    } else {
      metrics.sort((a, b) => a.tag.localeCompare(b.tag));
    }

    // Filter by search
    if (searchTerm) {
      metrics = metrics.filter(m =>
        m.tag.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    return metrics;
  }, [allJobs, sortBy, searchTerm]);

  // Find the max count for the progress bars
  const maxCount = useMemo(() => {
    return tagMetrics.length > 0 ? tagMetrics[0].count : 1;
  }, [tagMetrics]);

  // Total unique tags
  const totalTags = tagMetrics.length;
  const totalJobsWithTags = new Set(allJobs.filter(j => j.tags?.length > 0).map(j => j.id)).size;
  const jobsWithoutTags = allJobs.length - totalJobsWithTags;

  const toggleExpand = (tag: string) => {
    setExpandedTag(prev => prev === tag ? null : tag);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-40">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          <p className="font-black text-slate-400 uppercase tracking-widest text-[10px]">Analyse des offres...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-primary/30 transition-all">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Total Offres</p>
            <h4 className="text-2xl font-black text-slate-900">{allJobs.length}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:scale-110 transition-transform">
            <Briefcase size={24} />
          </div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-secondary/30 transition-all">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Tags Uniques</p>
            <h4 className="text-2xl font-black text-secondary">{totalTags}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-secondary/10 text-secondary flex items-center justify-center group-hover:scale-110 transition-transform">
            <Tag size={24} />
          </div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-cta/30 transition-all">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Offres Taggées</p>
            <h4 className="text-2xl font-black text-cta">{totalJobsWithTags}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-cta/10 text-cta flex items-center justify-center group-hover:scale-110 transition-transform">
            <BarChart3 size={24} />
          </div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-red-300 transition-all">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Sans Tags</p>
            <h4 className="text-2xl font-black text-red-500">{jobsWithoutTags}</h4>
          </div>
          <div className="w-12 h-12 rounded-xl bg-red-50 text-red-400 flex items-center justify-center group-hover:scale-110 transition-transform">
            <Tag size={24} />
          </div>
        </div>
      </div>

      {/* Search + Sort + Refresh Bar */}
      <div className="bg-white p-4 rounded-3xl border border-slate-200 shadow-sm">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div className="relative flex-1 md:max-w-md">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Rechercher un tag (ex: Informatique, Marketing...)"
              className="w-full pl-12 pr-4 py-2.5 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-sm"
            />
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => setSortBy(sortBy === 'count' ? 'alpha' : 'count')}
              className="flex items-center gap-2 px-4 py-2.5 bg-slate-50 border-2 border-slate-100 rounded-2xl text-sm font-bold text-slate-600 hover:border-primary/20 hover:text-primary transition-all"
            >
              <ArrowUpDown size={16} />
              {sortBy === 'count' ? 'Par nombre' : 'Alphabétique'}
            </button>
            <button
              onClick={fetchAllJobs}
              className="flex items-center gap-2 px-4 py-2.5 bg-primary text-white rounded-2xl text-sm font-bold shadow-lg shadow-primary/20 hover:bg-primary/90 transition-all active:scale-95"
            >
              <RefreshCw size={16} />
              Actualiser
            </button>
          </div>
        </div>
      </div>

      {/* Tags List with Expandable Details */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-slate-100">
          <h3 className="text-lg font-black uppercase tracking-tighter">
            Tous les Tags — {tagMetrics.length} résultat{tagMetrics.length > 1 ? 's' : ''}
          </h3>
          <p className="text-xs text-slate-400 font-medium mt-1">Cliquez sur un tag pour voir les offres correspondantes</p>
        </div>

        <div className="divide-y divide-slate-100">
          {tagMetrics.map((metric) => (
            <div key={metric.tag}>
              {/* Tag Row */}
              <button
                onClick={() => toggleExpand(metric.tag)}
                className={`w-full flex items-center gap-4 px-6 py-4 hover:bg-slate-50/50 transition-all text-left group ${
                  expandedTag === metric.tag ? 'bg-primary/[0.02]' : ''
                }`}
              >
                {/* Rank / Icon */}
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-black text-sm shrink-0 transition-all ${
                  expandedTag === metric.tag 
                    ? 'bg-primary text-white shadow-lg shadow-primary/20' 
                    : 'bg-slate-50 text-slate-400 border border-slate-200 group-hover:border-primary/30 group-hover:text-primary'
                }`}>
                  <Tag size={16} />
                </div>

                {/* Tag Name */}
                <div className="flex-1 min-w-0">
                  <p className="font-bold text-slate-900 text-sm truncate">{metric.tag}</p>
                </div>

                {/* Count Badge */}
                <div className="flex items-center gap-4 shrink-0">
                  <span className="text-xs font-black text-primary bg-primary/10 px-3 py-1.5 rounded-lg border border-primary/10">
                    {metric.count} offre{metric.count > 1 ? 's' : ''}
                  </span>

                  {/* Progress Bar */}
                  <div className="w-32 bg-slate-100 h-2 rounded-full overflow-hidden hidden md:block">
                    <div
                      className="h-full bg-primary rounded-full transition-all duration-700"
                      style={{ width: `${(metric.count / maxCount) * 100}%` }}
                    />
                  </div>

                  {/* Expand Arrow */}
                  <span className="text-slate-300 group-hover:text-primary transition-colors">
                    {expandedTag === metric.tag ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                  </span>
                </div>
              </button>

              {/* Expanded Job List */}
              {expandedTag === metric.tag && (
                <div className="bg-slate-50/50 border-t border-slate-100 px-6 py-4 animate-in slide-in-from-top-2 duration-300">
                  <div className="space-y-3 max-h-[400px] overflow-y-auto custom-scrollbar pr-2">
                    {metric.jobs.map((job) => (
                      <div
                        key={job.id}
                        className="flex items-center justify-between bg-white p-4 rounded-xl border border-slate-200 hover:border-primary/20 transition-all group/job"
                      >
                        <div className="flex items-center gap-3 min-w-0 flex-1">
                          <div className="w-8 h-8 rounded-lg bg-primary/5 text-primary flex items-center justify-center font-black text-xs shrink-0 border border-primary/10">
                            {job.company_name?.charAt(0) || 'J'}
                          </div>
                          <div className="min-w-0">
                            <p className="font-bold text-slate-900 text-sm truncate">{job.job_title}</p>
                            <div className="flex items-center gap-3 mt-1">
                              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider truncate">
                                {job.company_name || 'Non précisé'}
                              </span>
                              {job.location && (
                                <span className="text-[10px] font-medium text-slate-400 flex items-center gap-1 shrink-0">
                                  <MapPin size={9} /> {job.location}
                                </span>
                              )}
                              {job.deadline && (
                                <span className="text-[10px] font-medium text-slate-400 flex items-center gap-1 shrink-0">
                                  <Calendar size={9} /> {job.deadline}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>

                        {/* All tags for this job */}
                        <div className="flex items-center gap-2 shrink-0 ml-4">
                          <div className="flex flex-wrap gap-1 max-w-[200px]">
                            {(job.tags || []).slice(0, 3).map((t: string, i: number) => (
                              <span
                                key={i}
                                className={`text-[8px] font-black uppercase px-1.5 py-0.5 rounded-full ${
                                  t === metric.tag
                                    ? 'bg-primary text-white'
                                    : 'bg-slate-100 text-slate-400'
                                }`}
                              >
                                {t}
                              </span>
                            ))}
                            {(job.tags || []).length > 3 && (
                              <span className="text-[8px] font-black text-slate-300">+{job.tags.length - 3}</span>
                            )}
                          </div>
                          {(job.application_link || job.source_url) && (
                            <a
                              href={job.application_link || job.source_url}
                              target="_blank"
                              rel="noopener noreferrer"
                              onClick={(e) => e.stopPropagation()}
                              className="p-1.5 text-slate-300 hover:text-primary hover:bg-primary/5 rounded-lg transition-all opacity-0 group-hover/job:opacity-100"
                            >
                              <ExternalLink size={14} />
                            </a>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}

          {tagMetrics.length === 0 && (
            <div className="px-6 py-20 text-center">
              <Tag size={48} className="mx-auto text-slate-100 mb-4" />
              <p className="text-slate-400 font-bold uppercase tracking-widest text-sm">
                {searchTerm ? 'Aucun tag correspondant' : 'Aucun tag trouvé'}
              </p>
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm('')}
                  className="mt-4 text-primary text-xs font-black uppercase hover:underline"
                >
                  Réinitialiser la recherche
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default JobMetricsTab;
