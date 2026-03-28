import React from 'react';
import { ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const LegalLayout: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen bg-background p-4 md:p-8 selection:bg-accent">
      <div className="max-w-4xl mx-auto">
        <button 
          onClick={() => navigate('/')}
          className="neo-brutal-btn py-2 px-4 mb-8 flex items-center gap-2 text-sm"
        >
          <ArrowLeft size={18} /> RETOUR
        </button>
        <div className="neo-brutal-card !bg-white !p-8 md:!p-12">
          <h1 className="text-4xl md:text-6xl mb-12 uppercase italic leading-none">
            {title}
          </h1>
          <div className="prose prose-slate max-w-none font-medium leading-relaxed space-y-8 text-black">
            {children}
          </div>
        </div>
        <p className="text-center mt-12 font-black uppercase text-xs tracking-widest opacity-40">
          © 2026 DJORSSI-MATCH — ABIDJAN, CÔTE D'IVOIRE
        </p>
      </div>
    </div>
  );
};

export const TermsOfService: React.FC = () => (
  <LegalLayout title="Conditions Générales d'Utilisation (CGU)">
    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">1. Objet</h2>
      <p>
        Les présentes CGU ont pour objet de définir les modalités de mise à disposition des services de l'application 
        <strong> DJORSSI-MATCH</strong>, une plateforme de mise en relation directe pour l'emploi en Côte d'Ivoire.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">2. Description des Services</h2>
      <p>
        DJORSSI-MATCH permet aux chercheurs d'emploi de "swiper" des offres et aux recruteurs de sélectionner des profils. 
        En cas de "Match", les deux parties peuvent entrer en contact directement via les informations fournies.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">3. Engagements de l'Utilisateur</h2>
      <p>
        L'utilisateur s'engage à fournir des informations exactes et sincères sur son parcours professionnel (CV). 
        Toute fausse déclaration pourra entraîner la suspension immédiate du compte.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">4. Protection des Données</h2>
      <p>
        Conformément à la Loi n°2013-450 relative à la protection des données à caractère personnel en Côte d'Ivoire, 
        DJORSSI-MATCH s'engage à protéger les informations de ses utilisateurs. Pour plus de détails, consultez notre Politique de Confidentialité.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">5. Droit Applicable</h2>
      <p>
        Les présentes conditions sont régies par le droit en vigueur en République de Côte d'Ivoire. 
        En cas de litige, les tribunaux d'Abidjan seront seuls compétents.
      </p>
    </section>
  </LegalLayout>
);

export const PrivacyPolicy: React.FC = () => (
  <LegalLayout title="Politique de Confidentialité">
    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">1. Collecte des Données</h2>
      <p>
        Nous collectons les données suivantes nécessaires au recrutement : Nom, Prénoms, Email, Numéro de téléphone, 
        Genre et Curriculum Vitae (CV).
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">2. Utilisation des Données</h2>
      <p>
        Vos données sont utilisées exclusivement pour : 
        <ul className="list-disc pl-8 mt-2 space-y-2">
          <li>La création de votre profil candidat ou recruteur.</li>
          <li>La mise en relation avec des recruteurs en cas de "Match".</li>
          <li>L'envoi de candidatures par email via notre service Resend.</li>
        </ul>
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">3. Durée de Conservation</h2>
      <p>
        Les données des comptes inactifs sont supprimées après une période de 24 mois, sauf demande contraire de l'utilisateur.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">4. Vos Droits (ARTCI)</h2>
      <p>
        Conformément aux régulations de l'ARTCI, vous disposez d'un droit d'accès, de rectification et de suppression de vos données. 
        Vous pouvez exercer ce droit en nous contactant à : <strong>contact@djorssi-match.com</strong>.
      </p>
    </section>

    <section>
      <h2 className="text-2xl font-black uppercase mb-4 border-b-4 border-black inline-block">5. Sécurité</h2>
      <p>
        Nous utilisons des protocoles sécurisés (HTTPS) et les services cloud de Supabase pour garantir l'intégrité et la confidentialité de vos informations.
      </p>
    </section>
  </LegalLayout>
);
