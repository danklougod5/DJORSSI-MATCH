import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { Resend } from "npm:resend";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { PDFDocument, StandardFonts, rgb } from "npm:pdf-lib";

const resend = new Resend(Deno.env.get("RESEND_API_KEY") || "re_test_key");

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://djossi-match.vercel.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * Génère une lettre de motivation professionnelle en texte formaté
 * basée sur les informations du poste et du candidat
 */
function generateCoverLetterText(
  applicantName: string,
  jobTitle: string,
  companyName: string,
  jobDescription: string,
  coverLetterInstructions: string | null,
  userEmail: string,
  userSexe: string | null,
): string {
  const today = new Date();
  const dateStr = today.toLocaleDateString("fr-FR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });

  const e = userSexe === "Femme" ? "e" : "";

  const templates = [
    // Template 1: Classique et Formel
    `Madame, Monsieur,\n\nC'est avec un vif intérêt que je vous adresse ma candidature pour le poste de ${jobTitle} au sein de ${companyName}. Passionné${e} par mon métier et fort${e} d'une expérience solide, je suis convaincu${e} que mon profil correspond aux exigences de votre structure.`,
    
    // Template 2: Dynamique et Enthousiaste
    `Madame, Monsieur,\n\nJe suis ravi${e} de vous soumettre ma candidature pour le poste de ${jobTitle}. Votre entreprise, ${companyName}, est reconnue pour son excellence et je serais honoré${e} de mettre mon dynamisme et mes compétences à votre service.`,
    
    // Template 3: Analytique et Compétences
    `Madame, Monsieur,\n\nVotre offre pour le poste de ${jobTitle} a retenu toute mon attention. Mon parcours m'a permis de développer une expertise précise qui me semble être en parfaite adéquation avec les besoins de ${companyName}. Je souhaite aujourd'hui relever de nouveaux défis à vos côtés.`,
    
    // Template 4: Visionnaire et Ambitieux
    `Madame, Monsieur,\n\nLe développement de ${companyName} m'impressionne et c'est tout naturellement que je postule aujourd'hui au titre de ${jobTitle}. Je suis prêt${e} à m'investir pleinement pour contribuer à vos futurs succès et apporter une vision neuve à votre équipe.`,
    
    // Template 5: Direct et Efficace
    `Madame, Monsieur,\n\nActuellement à la recherche d'une nouvelle opportunité, le poste de ${jobTitle} au sein de votre établissement a suscité ma curiosité. Rigoureux${userSexe === "Femme" ? "se" : ""}, autonome et motivé${e}, je possède les atouts nécessaires pour réussir les missions que vous pourriez me confier.`,
    
    // Template 6: Valeurs et Engagement
    `Madame, Monsieur,\n\nPartageant les valeurs de ${companyName}, je vous propose mes services pour le poste de ${jobTitle}. Mon engagement et mon sens des responsabilités sont des atouts que je souhaite mettre à profit pour soutenir la croissance de votre entreprise.`,
    
    // Template 7: Adaptabilité et Evolution
    `Madame, Monsieur,\n\nMon profil d'expert polyvalent correspond idéalement au poste de ${jobTitle} que vous proposez. Ayant toujours su m'adapter à des environnements exigeants, je suis persuadé${e} que ma candidature retiendra votre attention pour intégrer ${companyName}.`,
    
    // Template 8: Proactif et Orienté Résultats
    `Madame, Monsieur,\n\nÀ la recherche d'un nouveau challenge professionnel, je vous adresse mon CV pour le poste de ${jobTitle}. Orienté${e} résultats et doté${e} d'un excellent esprit d'équipe, je souhaite contribuer activement à l'atteinte des objectifs de ${companyName}.`,
    
    // Template 9: Synthétique et Professionnel
    `Madame, Monsieur,\n\nJe me permets de vous contacter pour le recrutement d'un${userSexe === "Femme" ? "e" : ""} ${jobTitle}. Mon expérience acquise lors de mes précédentes missions fait de moi un${e} candidat${e} opérationnel${userSexe === "Femme" ? "le" : ""} immédiatement pour ${companyName}.`,
    
    // Template 10: Curieux et Innovateur
    `Madame, Monsieur,\n\nToujours à l'écoute des innovations de mon secteur, c'est avec enthousiasme que je postule pour le poste de ${jobTitle} chez ${companyName}. Je suis convaincu${e} que ma créativité et mon sérieux seront des vecteurs de réussite pour vos projets.`,
  ];

  // Sélection aléatoire d'un template (sécurisée)
  const randomArray = new Uint32Array(1);
  crypto.getRandomValues(randomArray);
  const randomIndex = randomArray[0] % templates.length;
  const introduction = templates[randomIndex];

  const letter = `
                                                                        Abidjan, le ${dateStr}


${applicantName}
Email : ${userEmail}



                                    Objet : Candidature au poste de ${jobTitle}


${introduction}

Motivé${e} et rigoureux${userSexe === "Femme" ? "se" : ""}, je souhaite mettre à profit mon expérience au service de votre structure. La description du poste correspond parfaitement à mes aspirations professionnelles et je suis convaincu${e} de pouvoir apporter une réelle valeur ajoutée.

Vous trouverez ci-joint mon curriculum vitae qui détaille plus amplement mon parcours. Je me tiens à votre entière disposition pour un entretien au cours duquel je pourrai vous exposer plus en détail mes motivations.

Dans l'attente de votre retour, je vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.


${applicantName}
`.trim();

  return letter;
}

/**
 * Génère un PDF complet et robuste à partir du texte, avec la bonne gestion
 * des accents français (WinAnsiEncoding) et retours à la ligne, via pdf-lib.
 */
async function generateSimplePDF(text: string): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  
  let page = pdfDoc.addPage([595, 842]); // Format A4
  const { width, height } = page.getSize();
  
  const fontSize = 11;
  const margin = 50;
  const maxWidth = width - margin * 2;
  
  let currentY = height - 80;

  // Split en paragraphes
  const paragraphs = text.split('\n');

  for (const para of paragraphs) {
    if (para.trim() === '') {
      currentY -= fontSize * 1.5;
      continue;
    }

    // Gestion de l'alignement pour l'en-tête, la date, l'objet (si ça commence par des espaces)
    let x = margin;
    let actualText = para;
    
    // Si la ligne commence par beaucoup d'espaces, on fait un petit "indent"
    if (para.startsWith('                                                                        ')) {
        x = width - margin - font.widthOfTextAtSize(para.trim(), fontSize);
        actualText = para.trim();
    } else if (para.startsWith('                                    ')) {
        x = margin + 100;
        actualText = para.trim();
    }

    // Word wrap
    const words = actualText.split(' ');
    let currentLine = '';

    for (const word of words) {
      // Nettoyage rapide de certains caractères invisibles (les accents normaux FR sont supportés)
      // On remplace juste certains tirets spéciaux ou guillemets par leurs version ASCII
      const cleanWord = word.replace(/’/g, "'").replace(/[«»]/g, '"');
      const testLine = currentLine.length > 0 ? `${currentLine} ${cleanWord}` : cleanWord;
      const textWidth = font.widthOfTextAtSize(testLine, fontSize);

      if (textWidth > maxWidth && currentLine !== '') {
        // Dessiner la ligne actuelle
        page.drawText(currentLine, {
          x,
          y: currentY,
          size: fontSize,
          font,
          color: rgb(0, 0, 0),
        });
        currentLine = cleanWord;
        currentY -= fontSize * 1.5;
        
        // Nouvelle page si on dépasse
        if (currentY < margin) {
          page = pdfDoc.addPage([595, 842]);
          currentY = height - margin;
        }
      } else {
        currentLine = testLine;
      }
    }

    // Dessiner la dernière ligne du paragraphe
    if (currentLine.trim() !== '') {
      page.drawText(currentLine, {
        x,
        y: currentY,
        size: fontSize,
        font,
        color: rgb(0, 0, 0),
      });
      currentY -= fontSize * 1.5;
      
      if (currentY < margin) {
        page = pdfDoc.addPage([595, 842]);
        currentY = height - margin;
      }
    }
  }

  const pdfBytes = await pdfDoc.save();
  return pdfBytes;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Initialize Supabase client with the user's token (least privilege)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser();

    if (authError || !user) {
      console.error("Auth error details:", authError);
      return new Response(JSON.stringify({ 
        error: "Unauthorized", 
        details: authError?.message || "Invalid or expired token"
      }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Parse the request body
    const { 
      jobTitle, 
      jobCompany, 
      cvUrl, 
      message, 
      userName, 
      userSexe,
      jobContactEmail,
      requiresCoverLetter,
      coverLetterInstructions,
      jobDescription,
    } = await req.json();

    // Normalisation du nom de l'entreprise : éviter le "Non spécifié"
    const isCompanyKnown = !!(jobCompany && jobCompany.toLowerCase() !== "non spécifié" && jobCompany.toLowerCase() !== "inconnu" && jobCompany.trim() !== "");
    const finalCompany = isCompanyKnown ? jobCompany : "votre structure ou votre entreprise";

    if (!cvUrl || !jobTitle) {
      return new Response(
        JSON.stringify({ error: "Missing required fields (cvUrl, jobTitle)" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // SSRF Protection: Validate the CV URL
    const validateUrl = (urlStr: string) => {
      const url = new URL(urlStr);
      const hostname = url.hostname.toLowerCase();
      
      const blockedPrefixes = ["10.", "192.168.", "172.16.", "172.17.", "172.18.", "172.19.", "172.20.", "172.21.", "172.22.", "172.23.", "172.24.", "172.25.", "172.26.", "172.27.", "172.28.", "172.29.", "172.30.", "172.31.", "127.", "0."];
      const blockedHosts = ["localhost", "169.254.169.254", "[::1]"];
      
      if (blockedHosts.includes(hostname) || blockedPrefixes.some(p => hostname.startsWith(p))) {
        throw new Error(`URL non autorisée : accès réseau privé refusé.`);
      }
      
      if (url.protocol !== "https:") {
        throw new Error("URL non autorisée : protocole HTTPS requis.");
      }
      
      return url.toString();
    };

    const safeCvUrl = validateUrl(cvUrl);

    // 1. Fetch the PDF CV from the provided URL
    console.log(`Fetching CV from: ${safeCvUrl.replace(/[\n\r]/g, "")}`);
    const cvResponse = await fetch(safeCvUrl);
    if (!cvResponse.ok) {
        throw new Error(`Failed to fetch CV file from the URL: ${safeCvUrl}`);
    }
    const cvArrayBuffer = await cvResponse.arrayBuffer();
    const cvBuffer = new Uint8Array(cvArrayBuffer);
    
    // Convert CV to base64 for Resend
    let binary = '';
    const bytes = new Uint8Array(cvBuffer);
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    const cvBase64 = btoa(binary);

    // 2. Prepare attachments array
    const applicantName = userName || user.email?.split("@")[0] || "Un candidat";
    const userEmail = user.email || "";
    
    const attachments: Array<{filename: string; content: string}> = [
      {
        filename: `CV_${applicantName.replace(/\s+/g, "_")}.pdf`,
        content: cvBase64,
      },
    ];

    // 3. Generate cover letter PDF if required
    let coverLetterGenerated = false;
    if (requiresCoverLetter) {
      console.log(`📝 Generating cover letter for: ${jobTitle.replace(/[\n\r]/g, "")}`);
      
      try {
        const coverLetterText = generateCoverLetterText(
          applicantName,
          jobTitle,
          finalCompany,
          jobDescription || "",
          coverLetterInstructions || null,
          userEmail,
          userSexe || null,
        );
        
        const coverLetterPDF = await generateSimplePDF(coverLetterText);
        
        // Convert to base64
        let clBinary = '';
        for (let i = 0; i < coverLetterPDF.byteLength; i++) {
          clBinary += String.fromCharCode(coverLetterPDF[i]);
        }
        const clBase64 = btoa(clBinary);
        
        attachments.push({
          filename: `Lettre_Motivation_${applicantName.replace(/\s+/g, "_")}_${jobTitle.substring(0, 30).replace(/[^a-zA-Z0-9]/g, "_")}.pdf`,
          content: clBase64,
        });
        
        coverLetterGenerated = true;
        console.log(`✅ Cover letter PDF generated successfully`);
      } catch (clError) {
        console.error(`❌ Error generating cover letter: ${clError}`);
        // Continue without cover letter - don't block the application
      }
    }

    // 4. Prepare the Email content (without accents to avoid special characters encoding issues)
    const coverLetterNote = coverLetterGenerated 
      ? `\n\nVeuillez egalement trouver en piece jointe ma lettre de motivation.`
      : "";

    const interestText = userSexe === "Femme" ? "interessee" : "interesse";
    const companyContext = isCompanyKnown ? `chez ${finalCompany}` : `au sein de ${finalCompany}`;

    const emailBody = message 
        ? message 
        : `Bonjour,\\n\\nJe suis tres ${interestText} par le poste de ${jobTitle} ${companyContext} vu sur Djorssi-Match.\\n\\nMon profil correspond a vos criteres et vous trouverez mon CV en piece jointe pour plus de details sur mon parcours.${coverLetterNote}\\n\\nCordialement,\\n${applicantName}\\nEmail: ${userEmail}`;

    // 5. Send email via Resend
    const targetEmail = "danklougod5@gmail.com"; 
    console.log(`Sending email for job: ${jobTitle.replace(/[\n\r]/g, "")} to ${targetEmail} (original target was ${(jobContactEmail || "").replace(/[\n\r]/g, "")}) with ${attachments.length} attachment(s)...`);
    
    // Removing accents from the applicantName and jobTitle just for the Email Subject/From metadata to guarantee delivery integrity
    const cleanName = applicantName.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const cleanTitle = jobTitle.normalize("NFD").replace(/[\u0300-\u036f]/g, "");

    const emailSubject = coverLetterGenerated
      ? `Candidature : ${cleanTitle} - ${cleanName} (CV + Lettre de Motivation)`
      : `Candidature : ${cleanTitle} - ${cleanName}`;

    const { data: resendData, error: resendError } = await resend.emails.send({
      from: `${cleanName} via Djorssi-Match <onboarding@resend.dev>`, 
      to: [targetEmail],
      reply_to: userEmail,
      subject: emailSubject,
      text: emailBody,
      attachments: attachments,
    });

    if (resendError) {
      console.error("Resend delivery error:", resendError);
      return new Response(JSON.stringify({ 
        error: "Resend error", 
        details: resendError.message,
        code: resendError.name
      }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    console.log("Resend success data:", resendData);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: coverLetterGenerated 
          ? "Email envoyé avec CV + Lettre de Motivation !" 
          : "Email envoyé avec CV !",
        coverLetterGenerated,
        resendData 
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error) {
    console.error("Internal Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
