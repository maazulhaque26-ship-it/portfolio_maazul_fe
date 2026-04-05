# =============================================================
#  fix-portfolio.ps1
#  Run this from your portfolio ROOT folder:
#    cd C:\path\to\portfolio
#    powershell -ExecutionPolicy Bypass -File fix-portfolio.ps1
# =============================================================

Write-Host "Starting portfolio fix..." -ForegroundColor Cyan

# ── Helper ────────────────────────────────────────────────────
function Write-File($path, $content) {
    $dir = Split-Path $path
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  wrote $path" -ForegroundColor Green
}

# ==============================================================
# 1. backend/server.js
# ==============================================================
Write-File "backend/server.js" @'
const express  = require('express');
const dotenv   = require('dotenv');
const cors     = require('cors');
const mongoose = require('mongoose');
const path     = require('path');

dotenv.config();
const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use('/api/auth',         require('./routes/authRoutes'));
app.use('/api/profile',      require('./routes/profileRoutes'));
app.use('/api/projects',     require('./routes/projectRoutes'));
app.use('/api/testimonials', require('./routes/testimonialRoutes'));
app.use('/api/contact',      require('./routes/contactRoutes'));
app.use('/api/blogs',        require('./routes/blogRoutes'));
app.use('/api/upload',       require('./routes/uploadRoutes'));
app.use('/api/portfolio/contact', require('./routes/contactRoutes'));

app.get('/api', (_req, res) => res.json({ status: 'ok', message: 'Portfolio API running' }));
app.use('/api/*', (req, res) => res.status(404).json({ message: `Route ${req.originalUrl} not found` }));
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => res.status(err.status||500).json({ message: err.message||'Server Error' }));

mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    console.log('MongoDB connected');
    app.listen(process.env.PORT||5000, () => console.log(`Server running on port ${process.env.PORT||5000}`));
  })
  .catch(err => { console.error(err.message); process.exit(1); });
'@

# ==============================================================
# 2. backend/controllers/profileController.js
# ==============================================================
Write-File "backend/controllers/profileController.js" @'
const Profile = require('../models/Profile');

const getProfile = async (req, res) => {
  try {
    let profile = await Profile.findOne({});
    if (!profile) profile = await Profile.create({});
    res.json(profile);
  } catch (err) { res.status(500).json({ message: err.message }); }
};

const updateProfile = async (req, res) => {
  try {
    let profile = await Profile.findOne({});
    if (!profile) profile = await Profile.create({});
    if (req.body.hero)     { profile.hero    = { ...(profile.hero?.toObject?.()||{}),    ...req.body.hero };    profile.markModified('hero'); }
    if (req.body.services !== undefined) { profile.services = req.body.services; profile.markModified('services'); }
    if (req.body.about)    { profile.about   = { ...(profile.about?.toObject?.()||{}),   ...req.body.about };   profile.markModified('about'); }
    if (req.body.contact)  { profile.contact = { ...(profile.contact?.toObject?.()||{}), ...req.body.contact }; profile.markModified('contact'); }
    if (req.body.tools     !== undefined) { profile.tools    = req.body.tools;    profile.markModified('tools'); }
    if (req.body.pricing   !== undefined) { profile.pricing  = req.body.pricing;  profile.markModified('pricing'); }
    if (req.body.timeline  !== undefined) { profile.timeline = req.body.timeline; profile.markModified('timeline'); }
    const saved = await profile.save();
    res.json(saved);
  } catch (err) { res.status(400).json({ message: err.message }); }
};

module.exports = { getProfile, updateProfile };
'@

# ==============================================================
# 3. backend/controllers/projectController.js
# ==============================================================
Write-File "backend/controllers/projectController.js" @'
const Project = require('../models/Project');

const getProjects    = async (req, res) => { try { res.json(await Project.find({}).sort({createdAt:-1})); } catch(e){ res.status(500).json({message:e.message}); } };
const createProject  = async (req, res) => {
  try {
    const {title,description,technologies,imageUrl,githubUrl,liveViewUrl,isFeatured} = req.body;
    if (!title||!description||!imageUrl) return res.status(400).json({message:'title, description and imageUrl required'});
    const p = await Project.create({title,description,technologies:Array.isArray(technologies)?technologies:[],imageUrl,githubUrl:githubUrl||'',liveViewUrl:liveViewUrl||'',isFeatured:isFeatured||false});
    res.status(201).json(p);
  } catch(e){ res.status(400).json({message:e.message}); }
};
const updateProject  = async (req, res) => {
  try {
    const p = await Project.findById(req.params.id);
    if (!p) return res.status(404).json({message:'Project not found'});
    const {title,description,technologies,imageUrl,githubUrl,liveViewUrl,isFeatured} = req.body;
    if (title)        p.title        = title;
    if (description)  p.description  = description;
    if (technologies) p.technologies = technologies;
    if (imageUrl)     p.imageUrl     = imageUrl;
    if (githubUrl   !== undefined) p.githubUrl   = githubUrl;
    if (liveViewUrl !== undefined) p.liveViewUrl = liveViewUrl;
    if (isFeatured  !== undefined) p.isFeatured  = isFeatured;
    res.json(await p.save());
  } catch(e){ res.status(400).json({message:e.message}); }
};
const deleteProject  = async (req, res) => {
  try {
    const p = await Project.findById(req.params.id);
    if (!p) return res.status(404).json({message:'Project not found'});
    await p.deleteOne(); res.json({message:'Project removed'});
  } catch(e){ res.status(500).json({message:e.message}); }
};
module.exports = { getProjects, createProject, updateProject, deleteProject };
'@

# ==============================================================
# 4. backend/controllers/testimonialController.js
# ==============================================================
Write-File "backend/controllers/testimonialController.js" @'
const Testimonial = require('../models/Testimonial');

const getTestimonials   = async (req,res) => { try { res.json(await Testimonial.find({}).sort({createdAt:-1})); } catch(e){ res.status(500).json({message:e.message}); } };
const createTestimonial = async (req,res) => {
  try {
    const {name,clientName,company,role,text,rating,imageUrl} = req.body;
    const n = clientName||name, r = role||company;
    if (!n||!r||!text) return res.status(400).json({message:'name, company and text required'});
    res.status(201).json(await Testimonial.create({clientName:n,role:r,text,rating:rating||5,imageUrl:imageUrl||''}));
  } catch(e){ res.status(400).json({message:e.message}); }
};
const updateTestimonial = async (req,res) => {
  try {
    const t = await Testimonial.findById(req.params.id);
    if (!t) return res.status(404).json({message:'Not found'});
    const {name,clientName,company,role,text,rating,imageUrl} = req.body;
    if (clientName||name) t.clientName = clientName||name;
    if (role||company)    t.role       = role||company;
    if (text)             t.text       = text;
    if (rating  !==undefined) t.rating   = rating;
    if (imageUrl!==undefined) t.imageUrl = imageUrl;
    res.json(await t.save());
  } catch(e){ res.status(400).json({message:e.message}); }
};
const deleteTestimonial = async (req,res) => {
  try {
    const t = await Testimonial.findById(req.params.id);
    if (!t) return res.status(404).json({message:'Not found'});
    await t.deleteOne(); res.json({message:'Removed'});
  } catch(e){ res.status(500).json({message:e.message}); }
};
module.exports = { getTestimonials, createTestimonial, updateTestimonial, deleteTestimonial };
'@

# ==============================================================
# 5. backend/routes/testimonialRoutes.js
# ==============================================================
Write-File "backend/routes/testimonialRoutes.js" @'
const express = require('express');
const router  = express.Router();
const { getTestimonials,createTestimonial,updateTestimonial,deleteTestimonial } = require('../controllers/testimonialController');
const { protectAdmin } = require('../middleware/authMiddleware');
router.route('/').get(getTestimonials).post(protectAdmin,createTestimonial);
router.route('/:id').put(protectAdmin,updateTestimonial).delete(protectAdmin,deleteTestimonial);
module.exports = router;
'@

# ==============================================================
# 6. backend/controllers/contactController.js
# ==============================================================
Write-File "backend/controllers/contactController.js" @'
const ContactMessage = require('../models/ContactMessage');
const sendMessage  = async (req,res) => {
  try {
    const {name,email,phone,interestedIn,message} = req.body;
    if (!name||!email||!message) return res.status(400).json({success:false,message:'name, email and message required'});
    await ContactMessage.create({name,email,phone:phone||'',interestedIn:interestedIn||'',message});
    res.status(201).json({success:true,message:'Message sent.'});
  } catch(e){ res.status(400).json({success:false,message:e.message}); }
};
const getMessages  = async (req,res) => { try { res.json(await ContactMessage.find().sort({createdAt:-1})); } catch(e){ res.status(500).json({message:e.message}); } };
const deleteMessage = async (req,res) => {
  try {
    const m = await ContactMessage.findById(req.params.id);
    if (!m) return res.status(404).json({message:'Not found'});
    await m.deleteOne(); res.json({message:'Deleted'});
  } catch(e){ res.status(500).json({message:e.message}); }
};
module.exports = { sendMessage, getMessages, deleteMessage };
'@

# ==============================================================
# 7. backend/routes/contactRoutes.js
# ==============================================================
Write-File "backend/routes/contactRoutes.js" @'
const express = require('express');
const router  = express.Router();
const { sendMessage,getMessages,deleteMessage } = require('../controllers/contactController');
const { protectAdmin } = require('../middleware/authMiddleware');
router.route('/').post(sendMessage).get(protectAdmin,getMessages);
router.route('/:id').delete(protectAdmin,deleteMessage);
module.exports = router;
'@

# ==============================================================
# 8. backend/controllers/blogController.js
# ==============================================================
Write-File "backend/controllers/blogController.js" @'
const Blog = require('../models/Blog');
const getBlogs    = async (req,res) => { try { res.json(await Blog.find().sort({createdAt:-1})); } catch(e){ res.status(500).json({message:e.message}); } };
const createBlog  = async (req,res) => {
  try {
    const {title,content,imageUrl,category} = req.body;
    if (!title||!content) return res.status(400).json({message:'title and content required'});
    res.status(201).json(await Blog.create({title,content,imageUrl:imageUrl||'',category:category||'General'}));
  } catch(e){ res.status(400).json({message:e.message}); }
};
const updateBlog  = async (req,res) => {
  try {
    const b = await Blog.findByIdAndUpdate(req.params.id,req.body,{new:true,runValidators:true});
    if (!b) return res.status(404).json({message:'Not found'});
    res.json(b);
  } catch(e){ res.status(400).json({message:e.message}); }
};
const deleteBlog  = async (req,res) => {
  try {
    const b = await Blog.findByIdAndDelete(req.params.id);
    if (!b) return res.status(404).json({message:'Not found'});
    res.json({message:'Removed'});
  } catch(e){ res.status(500).json({message:e.message}); }
};
module.exports = { getBlogs, createBlog, updateBlog, deleteBlog };
'@

# ==============================================================
# 9. backend/models/Testimonial.js
# ==============================================================
Write-File "backend/models/Testimonial.js" @'
const mongoose = require('mongoose');
const testimonialSchema = new mongoose.Schema({
  clientName: { type: String, required: true },
  role:       { type: String, required: true },
  text:       { type: String, required: true },
  rating:     { type: Number, default: 5, min: 1, max: 5 },
  imageUrl:   { type: String, default: '' },
}, { timestamps: true });
module.exports = mongoose.model('Testimonial', testimonialSchema);
'@

# ==============================================================
# 10. frontend/src/context/PortfolioContext.jsx
# ==============================================================
Write-File "frontend/src/context/PortfolioContext.jsx" @'
import { createContext, useState, useEffect, useContext, useCallback } from "react";
import { AuthContext } from "./AuthContext";

export const PortfolioContext = createContext();
const API = "http://localhost:5000";

export const PortfolioProvider = ({ children }) => {
  const { user } = useContext(AuthContext);
  const [profile,  setProfile]  = useState(null);
  const [projects, setProjects] = useState([]);
  const [loading,  setLoading]  = useState(true);

  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      const [profRes, projRes] = await Promise.all([
        fetch(`${API}/api/profile`),
        fetch(`${API}/api/projects`),
      ]);
      const profData = profRes.ok  ? await profRes.json() : null;
      const projData = projRes.ok  ? await projRes.json() : [];
      setProfile(profData);
      setProjects(Array.isArray(projData) ? projData : []);
    } catch (err) {
      console.error("[PortfolioContext]", err.message);
      setProfile(null); setProjects([]);
    } finally { setLoading(false); }
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  const getImageUrl = useCallback((url) => {
    if (!url) return null;
    if (url.startsWith("http://") || url.startsWith("https://")) return url;
    return `${API}${url.startsWith("/") ? "" : "/"}${url}`;
  }, []);

  const services = Array.isArray(profile?.services) ? profile.services : [];

  return (
    <PortfolioContext.Provider value={{
      profile, services, projects, loading,
      getImageUrl, refreshData: loadAll, refreshProfile: loadAll,
      user, isEditing: false, draft: null, API,
    }}>
      {children}
    </PortfolioContext.Provider>
  );
};
'@

# ==============================================================
# 11. frontend/src/App.jsx
# ==============================================================
Write-File "frontend/src/App.jsx" @'
import { useContext } from "react";
import { Routes, Route } from "react-router-dom";
import { AuthContext, AuthProvider } from "./context/AuthContext";
import { PortfolioProvider } from "./context/PortfolioContext";
import Home from "./pages/Home";
import SecretLogin from "./pages/SecretLogin";
import AdminDashboard from "./pages/admin/AdminDashboard";

const Navbar = () => (
  <nav className="absolute top-0 w-full z-50 py-6 px-4 md:px-12 flex justify-between items-center text-white">
    <div className="flex items-center gap-2">
      <div className="w-10 h-10 bg-olivia-gold rounded-full flex items-center justify-center font-bold text-black text-xl">O</div>
      <span className="font-bold text-xl tracking-wide">Olivia</span>
    </div>
    <div className="hidden md:flex gap-8 bg-black/20 backdrop-blur-md px-8 py-3 rounded-full border border-white/10">
      {[["Home","#home"],["Services","#services"],["About","#about"],["Projects","#projects"],["Blogs","#blogs"]].map(([l,h])=>(
        <a key={h} href={h} className="hover:text-olivia-gold transition-colors text-sm uppercase tracking-wider">{l}</a>
      ))}
    </div>
    <button onClick={()=>document.querySelector("#contact")?.scrollIntoView({behavior:"smooth"})}
      className="bg-white text-black font-semibold px-6 py-2.5 rounded-full hover:bg-olivia-gold transition-colors">
      Contact Me
    </button>
  </nav>
);

const AppContent = () => {
  const { isAuthenticated } = useContext(AuthContext);
  return (
    <div className="relative font-sans">
      <Routes>
        <Route path="/" element={<><Navbar /><Home /></>} />
        <Route path="/authenticate-master" element={isAuthenticated ? <AdminDashboard /> : <SecretLogin />} />
      </Routes>
    </div>
  );
};

function App() {
  return (
    <AuthProvider>
      <PortfolioProvider>
        <AppContent />
      </PortfolioProvider>
    </AuthProvider>
  );
}
export default App;
'@

# ==============================================================
# 12. frontend/src/components/HeroSection.jsx
# ==============================================================
Write-File "frontend/src/components/HeroSection.jsx" @'
import { useEffect, useRef, useContext } from "react";
import gsap from "gsap";
import { PortfolioContext } from "../context/PortfolioContext";

const HeroSection = () => {
  const { profile, loading, getImageUrl } = useContext(PortfolioContext);
  const data = profile?.hero;
  const sectionRef = useRef(null);
  const did = useRef(false);

  useEffect(() => {
    if (!data || !sectionRef.current || did.current) return;
    did.current = true;
    const ctx = gsap.context(() => {
      gsap.from(".hero-text > *", { y:40, opacity:0, duration:1, stagger:0.15, ease:"power3.out" });
      gsap.from(".hero-image",    { scale:0.85, opacity:0, rotation:3, duration:1.2, ease:"back.out(1.7)", delay:0.3 });
    }, sectionRef);
    return () => ctx.revert();
  }, [data]);

  if (loading) return (
    <section id="home" className="py-20 md:py-32 px-4 md:px-12 bg-white flex items-center justify-center min-h-[70vh]">
      <div className="flex flex-col items-center gap-4">
        <div className="w-12 h-12 border-4 border-olivia-gold border-t-transparent rounded-full animate-spin" />
        <p className="text-sm uppercase tracking-widest text-olivia-text-light">Loading...</p>
      </div>
    </section>
  );
  if (!data) return null;

  const avatarSrc = getImageUrl(data?.profileImage || data?.avatarUrl);

  return (
    <section ref={sectionRef} id="home" className="py-20 md:py-32 px-4 md:px-12 bg-white flex flex-col lg:flex-row items-center justify-between overflow-hidden">
      <div className="hero-text w-full lg:w-1/2 space-y-6 z-10">
        <div className="inline-block border-2 border-olivia-gold/50 text-olivia-text px-6 py-2 rounded-tl-xl rounded-br-xl rounded-tr-md rounded-bl-md font-serif text-lg">Hello There!</div>
        <h1 className="text-5xl lg:text-7xl font-bold font-serif leading-tight text-olivia-text">
          I'm <span className="text-olivia-gold relative inline-block">
            <span>{data?.name||""}</span>
            <svg className="absolute w-full h-4 -bottom-2 left-0 text-olivia-gold/50" viewBox="0 0 100 20" preserveAspectRatio="none">
              <path d="M0 10 Q 25 20 50 10 T 100 10" fill="transparent" stroke="currentColor" strokeWidth="4"/>
            </svg>
          </span>,<br/>
          <span className="block mt-2">{data?.headline||""}</span>
          {data?.location && <span className="text-olivia-text-light text-3xl lg:text-4xl">{data.location}</span>}
        </h1>
        {data?.bio && <div className="text-olivia-text-light max-w-prose text-lg leading-relaxed font-sans mt-6">
          <p dangerouslySetInnerHTML={{__html: data.bio.replace(/\n/g,"<br/>")}} />
        </div>}
        <div className="flex flex-wrap items-center gap-6 pt-8">
          <a href="#projects" className="bg-olivia-green text-white pl-8 pr-4 py-3 rounded-full font-semibold hover:bg-[#123023] transition-colors flex items-center gap-4">
            View My Work <span className="bg-olivia-gold text-olivia-green w-10 h-10 rounded-full flex items-center justify-center shadow-md">▶</span>
          </a>
          <a href="#contact" className="border-2 border-olivia-gray text-olivia-text px-8 py-4 rounded-full font-semibold hover:border-olivia-gold transition-colors">Hire Me</a>
          {data?.cvUrl && <a href={getImageUrl(data.cvUrl)} target="_blank" rel="noopener noreferrer" className="text-olivia-text-light text-sm underline underline-offset-4 decoration-olivia-gold/50 hover:text-olivia-gold transition-colors">Download CV</a>}
        </div>
      </div>
      <div className="hero-image w-full lg:w-1/2 relative mt-20 lg:mt-0 flex justify-center lg:justify-end">
        <div className="relative w-[320px] h-[320px] md:w-[500px] md:h-[500px]">
          <div className="absolute inset-x-0 bottom-0 top-12 bg-olivia-gold rounded-full transform -rotate-6 scale-95 z-0"/>
          {avatarSrc ? <img src={avatarSrc} alt="avatar" className="w-full h-full object-cover rounded-b-full relative z-10 drop-shadow-2xl object-top bg-gray-100" onError={e=>{e.currentTarget.style.display="none";}}/> :
            <div className="w-full h-full rounded-b-full relative z-10 bg-olivia-green/10 flex items-center justify-center"><span className="text-8xl text-olivia-green/20">👤</span></div>}
          <div className="absolute top-10 right-0 bg-olivia-green text-white text-xs font-bold uppercase tracking-wider w-24 h-24 rounded-full flex flex-col items-center justify-center p-2 text-center transform rotate-12 z-20 shadow-lg border-[3px] border-white">
            <span className="text-olivia-gold text-sm">{data?.yearsExp||"15+"} Years</span>Experience
          </div>
          <div className="absolute bottom-24 -left-8 bg-olivia-green text-white px-6 py-3 rounded-full font-semibold shadow-lg z-20 hover:scale-105 transition-transform">{data?.headline||"Designer"}</div>
          <div className="absolute bottom-8 right-8 bg-olivia-gold text-black px-6 py-3 rounded-full font-semibold shadow-lg z-20 hover:scale-105 transition-transform">{data?.location||"Available"}</div>
        </div>
      </div>
    </section>
  );
};
export default HeroSection;
'@

# ==============================================================
# 13. frontend/src/components/ServicesSection.jsx
# ==============================================================
Write-File "frontend/src/components/ServicesSection.jsx" @'
import { useContext, useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { PortfolioContext } from "../context/PortfolioContext";
gsap.registerPlugin(ScrollTrigger);

const ServicesSection = () => {
  const { services, loading, getImageUrl } = useContext(PortfolioContext);
  const sectionRef = useRef(null);

  useEffect(() => {
    if (!services.length || !sectionRef.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".service-card", { scrollTrigger:{ trigger:sectionRef.current, start:"top 80%" }, y:60, opacity:0, duration:0.8, stagger:0.2, ease:"power2.out" });
    }, sectionRef);
    return () => ctx.revert();
  }, [services]);

  const renderIcon = (s) => {
    const raw = s?.icon;
    if (!raw) return <span className="text-3xl">✦</span>;
    const isImg = raw.startsWith("/uploads") || raw.startsWith("http") || /\.(jpg|jpeg|png|webp|gif|svg)$/i.test(raw);
    if (isImg) return <img src={getImageUrl(raw)} alt={s.title} className="w-10 h-10 object-contain" onError={e=>{e.currentTarget.style.display="none";}}/>;
    return <span className="text-3xl">{raw}</span>;
  };

  if (loading) return (
    <section id="services" className="bg-olivia-green/5 py-20 md:py-32 px-4 md:px-12 border-b border-gray-100">
      <div className="max-w-7xl mx-auto flex justify-center items-center min-h-[200px]">
        <div className="w-10 h-10 border-4 border-olivia-gold border-t-transparent rounded-full animate-spin"/>
      </div>
    </section>
  );

  if (!services.length) return (
    <section id="services" className="bg-olivia-green/5 py-20 md:py-32 px-4 md:px-12 border-b border-gray-100">
      <div className="max-w-7xl mx-auto text-center py-16 border-2 border-dashed border-gray-200 rounded-3xl text-gray-400">
        <p className="text-lg font-semibold">No services added yet.</p>
        <p className="text-sm mt-1">Add services from the Admin Panel.</p>
      </div>
    </section>
  );

  return (
    <section ref={sectionRef} id="services" className="bg-olivia-green/5 py-20 md:py-32 px-4 md:px-12 border-b border-gray-100">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-wrap justify-between items-end mb-12 gap-6">
          <div>
            <div className="flex items-center gap-2 text-olivia-gold mb-2 font-bold uppercase tracking-wider text-sm">
              <span className="w-4 h-1 bg-olivia-gold inline-block"/> Services
            </div>
            <h2 className="text-4xl md:text-5xl font-serif font-bold text-olivia-text"><span className="text-olivia-gold">Services</span> I Provide</h2>
          </div>
          <button onClick={()=>document.querySelector("#contact")?.scrollIntoView({behavior:"smooth"})}
            className="hidden md:flex items-center gap-3 bg-olivia-green text-white px-6 py-3 rounded-full hover:bg-olivia-gold hover:text-black transition-all">
            Get In Touch <span className="bg-white text-olivia-green w-6 h-6 rounded-full flex items-center justify-center text-xs">▶</span>
          </button>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {services.map((service, index) => (
            <div key={service?._id||index} className="service-card bg-white p-8 rounded-[32px] shadow-sm border border-gray-100 group hover:-translate-y-3 hover:shadow-xl transition-all duration-300">
              <div className="w-16 h-16 bg-olivia-green/5 rounded-xl flex items-center justify-center mb-6 shadow-sm group-hover:bg-olivia-gold/10 transition-colors overflow-hidden">{renderIcon(service)}</div>
              <h3 className="text-2xl font-bold font-serif text-olivia-text mb-4">{service?.title||""}</h3>
              <p className="text-olivia-text-light text-sm leading-relaxed mb-6">
                <span dangerouslySetInnerHTML={{__html: service?.description?.replace(/\n/g,"<br/>")||""}}/>
              </p>
              <a href="#contact" className="flex items-center gap-2 text-olivia-text text-sm font-bold group-hover:text-olivia-gold transition-colors">Learn more <span className="text-olivia-gold">→</span></a>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
export default ServicesSection;
'@

# ==============================================================
# 14. frontend/src/components/ProjectsSection.jsx
# ==============================================================
Write-File "frontend/src/components/ProjectsSection.jsx" @'
import { useEffect, useRef, useContext } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { PortfolioContext } from "../context/PortfolioContext";
gsap.registerPlugin(ScrollTrigger);

const ProjectsSection = () => {
  const { projects, loading, getImageUrl } = useContext(PortfolioContext);
  const sectionRef = useRef(null);

  useEffect(() => {
    if (!projects.length || !sectionRef.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".project-card", { scrollTrigger:{ trigger:sectionRef.current, start:"top 75%" }, y:80, opacity:0, duration:0.8, stagger:0.2, ease:"power2.out" });
    }, sectionRef);
    return () => ctx.revert();
  }, [projects]);

  if (loading) return (
    <section id="projects" className="py-20 md:py-32 bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 md:px-12 flex justify-center items-center min-h-[300px]">
        <div className="w-10 h-10 border-4 border-olivia-gold border-t-transparent rounded-full animate-spin"/>
      </div>
    </section>
  );

  return (
    <section ref={sectionRef} id="projects" className="py-20 md:py-32 bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 md:px-12">
        <div className="flex flex-wrap justify-between items-end mb-12 gap-6">
          <div>
            <div className="flex items-center gap-2 text-olivia-text-light mb-2 font-bold uppercase tracking-wider text-xs"><span className="w-4 h-1 bg-olivia-gold inline-block"/> My Portfolio</div>
            <h2 className="text-4xl md:text-5xl font-serif font-bold text-olivia-text">My Latest <span className="text-olivia-gold">Projects</span></h2>
          </div>
        </div>
        {!projects.length ? (
          <div className="text-center text-gray-400 py-16 border-2 border-dashed border-gray-200 rounded-3xl">
            <p className="text-lg">No projects added yet.</p>
            <p className="text-sm mt-1">Add projects from the Admin Panel.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
            {projects.map((project,index) => {
              const imgSrc = getImageUrl(project?.imageUrl);
              return (
                <div key={project?._id||index} className="project-card bg-white rounded-[32px] p-6 shadow-xl border border-gray-100 group hover:shadow-2xl transition-all duration-300">
                  <div className="w-full h-[300px] bg-gray-100 rounded-2xl overflow-hidden mb-6">
                    {imgSrc ? <img src={imgSrc} alt={project?.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700" onError={e=>{e.currentTarget.src="https://placehold.co/600x400/f3f4f6/9ca3af?text=No+Image";}}/> :
                      <div className="w-full h-full flex items-center justify-center text-gray-300 text-sm">No image</div>}
                  </div>
                  {Array.isArray(project?.technologies)&&project.technologies.length>0&&(
                    <div className="flex gap-2 mb-4 flex-wrap">
                      {project.technologies.map((t,i)=><span key={i} className="bg-olivia-gold text-black px-4 py-1.5 rounded-full text-xs font-bold shadow-sm">{t}</span>)}
                    </div>
                  )}
                  <div className="flex justify-between items-start gap-4">
                    <div className="flex-1 min-w-0">
                      <h3 className="text-2xl font-bold font-serif text-olivia-text mb-2 line-clamp-1 group-hover:text-olivia-gold transition-colors">{project?.title||"Untitled"}</h3>
                      {project?.description&&<p className="text-olivia-text-light text-sm line-clamp-2 mb-4">{project.description}</p>}
                      <div className="flex flex-wrap gap-2 mt-3">
                        {(project?.liveViewUrl||project?.liveLink)&&<a href={project.liveViewUrl||project.liveLink} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-bold uppercase bg-olivia-green text-white hover:bg-olivia-gold hover:text-black transition-all">Live Link</a>}
                        {(project?.githubUrl||project?.githubLink)&&<a href={project.githubUrl||project.githubLink} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-bold uppercase border border-gray-200 text-olivia-text hover:bg-olivia-green hover:text-white transition-all">GitHub</a>}
                      </div>
                    </div>
                    {(project?.liveViewUrl||project?.liveLink)&&<a href={project.liveViewUrl||project.liveLink} target="_blank" rel="noopener noreferrer" className="w-10 h-10 bg-olivia-green text-white rounded-full flex items-center justify-center hover:bg-olivia-gold hover:text-black transition-colors group-hover:-rotate-45 duration-300 shadow-md flex-shrink-0">→</a>}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
};
export default ProjectsSection;
'@

# ==============================================================
# 15. frontend/src/pages/admin/AdminDashboard.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminDashboard.jsx" @'
import { useState, useContext } from "react";
import { PortfolioContext } from "../../context/PortfolioContext";
import AdminSidebar      from "./AdminSidebar";
import AdminProfile      from "./AdminProfile";
import AdminProjects     from "./AdminProjects";
import AdminServices     from "./AdminServices";
import AdminBlogs        from "./AdminBlogs";
import AdminTestimonials from "./AdminTestimonials";

const AdminDashboard = () => {
  const [activeTab, setActiveTab] = useState("profile");
  const { refreshData } = useContext(PortfolioContext);
  const renderContent = () => {
    switch (activeTab) {
      case "profile":      return <AdminProfile      onSave={refreshData}/>;
      case "projects":     return <AdminProjects     onSave={refreshData}/>;
      case "services":     return <AdminServices     onSave={refreshData}/>;
      case "blogs":        return <AdminBlogs        onSave={refreshData}/>;
      case "testimonials": return <AdminTestimonials onSave={refreshData}/>;
      default: return (
        <div className="flex items-center justify-center h-[60vh]">
          <div className="text-center p-10 bg-white rounded-3xl shadow-sm border border-gray-100 max-w-md w-full">
            <span className="text-5xl mb-4 block opacity-50">🚧</span>
            <h3 className="text-xl font-bold font-serif mb-2">Under Construction</h3>
          </div>
        </div>
      );
    }
  };
  return (
    <div className="flex flex-col md:flex-row h-screen bg-[#f8fafc] text-gray-800 font-sans overflow-hidden w-full absolute inset-0 z-[100]">
      <AdminSidebar activeTab={activeTab} setActiveTab={setActiveTab}/>
      <div className="flex-1 overflow-y-auto px-6 md:px-12 py-8 md:py-10">
        <div className="mb-10">
          <h1 className="text-3xl font-serif font-bold text-olivia-green capitalize">Manage {activeTab}</h1>
          <p className="text-gray-500 text-sm mt-1">Control your portfolio data securely.</p>
        </div>
        {renderContent()}
      </div>
    </div>
  );
};
export default AdminDashboard;
'@

# ==============================================================
# 16. frontend/src/pages/admin/AdminProfile.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminProfile.jsx" @'
import { useState, useContext, useEffect } from "react";
import { PortfolioContext } from "../../context/PortfolioContext";
import { AuthContext }      from "../../context/AuthContext";

const Toast = ({msg,type}) => !msg ? null : (
  <div className={`fixed bottom-6 right-6 z-50 px-6 py-3 rounded-2xl border font-semibold text-sm shadow-xl ${type==="error"?"bg-red-50 text-red-700 border-red-200":"bg-green-50 text-green-700 border-green-200"}`}>{msg}</div>
);

const AdminProfile = ({onSave}) => {
  const { profile, getImageUrl, refreshData } = useContext(PortfolioContext);
  const { user } = useContext(AuthContext);
  const [fields, setFields] = useState({name:"",yearsExp:"",headline:"",location:"",bio:"",avatarUrl:"",cvUrl:""});
  const [uploading, setUploading] = useState(false);
  const [saving,    setSaving]    = useState(false);
  const [toast,     setToast]     = useState({msg:"",type:"success"});
  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast({msg:"",type:"success"}),3500); };

  useEffect(() => {
    if (profile?.hero) setFields({name:profile.hero.name??"",yearsExp:profile.hero.yearsExp??"",headline:profile.hero.headline??"",location:profile.hero.location??"",bio:profile.hero.bio??"",avatarUrl:profile.hero.avatarUrl??"",cvUrl:profile.hero.cvUrl??""});
  }, [profile]);

  const handleImageUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    setUploading(true);
    const form = new FormData(); form.append("image", file);
    try {
      const res  = await fetch("http://localhost:5000/api/upload", {method:"POST",headers:{Authorization:`Bearer ${user.token}`},body:form});
      const data = await res.json();
      if (res.ok) { setFields(p=>({...p,avatarUrl:data.url})); showToast("Avatar uploaded ✓"); }
      else showToast(data.message||"Upload failed","error");
    } catch { showToast("Network error — is the backend running?","error"); }
    finally { setUploading(false); }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    setSaving(true);
    try {
      const res  = await fetch("http://localhost:5000/api/profile",{method:"PUT",headers:{"Content-Type":"application/json",Authorization:`Bearer ${user.token}`},body:JSON.stringify({hero:fields})});
      const data = await res.json();
      if (res.ok) { showToast("Profile saved ✓"); refreshData?.(); onSave?.(); }
      else showToast(data.message||"Save failed","error");
    } catch { showToast("Network error — is the backend running?","error"); }
    finally { setSaving(false); }
  };

  const avatarSrc = getImageUrl(fields.avatarUrl);
  return (
    <>
      <Toast {...toast}/>
      <div className="bg-white rounded-[32px] shadow-sm border border-gray-100 p-8 md:p-10 max-w-3xl">
        <form onSubmit={handleSave} className="space-y-6">
          <div className="flex items-center gap-8 mb-8 pb-8 border-b border-gray-100">
            <div className="w-32 h-32 rounded-full overflow-hidden border-4 border-gray-50 bg-gray-100 flex items-center justify-center shrink-0">
              {uploading ? <span className="text-gray-400 font-bold text-xs animate-pulse">Uploading…</span>
                : avatarSrc ? <img src={avatarSrc} alt="avatar" className="w-full h-full object-cover" onError={e=>{e.currentTarget.style.display="none";}}/>
                : <span className="text-5xl text-gray-300">👤</span>}
            </div>
            <div className="flex-1">
              <label className="block text-sm font-bold text-gray-800 mb-2">Primary Avatar</label>
              <input type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={handleImageUpload} disabled={uploading}
                className="block w-full text-sm text-gray-500 file:mr-4 file:py-2.5 file:px-6 file:rounded-full file:border-0 file:text-sm file:font-bold file:bg-olivia-gold/10 file:text-olivia-green hover:file:bg-olivia-gold/20 disabled:opacity-60"/>
              <p className="text-xs text-gray-400 mt-2">JPG, PNG, WEBP. Max 5MB.</p>
              {fields.avatarUrl && <p className="text-[10px] text-olivia-green mt-1 font-mono truncate">{fields.avatarUrl}</p>}
            </div>
          </div>
          <div className="grid grid-cols-2 gap-6">
            {[["Display Name","name",false,""],["Experience Badge","yearsExp",false,"Ex. 15+"]].map(([label,key,req,ph])=>(
              <div key={key}>
                <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">{label}</label>
                <input type="text" required={req} placeholder={ph} value={fields[key]} onChange={e=>setFields({...fields,[key]:e.target.value})}
                  className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:outline-none focus:ring-2 focus:ring-olivia-gold font-medium"/>
              </div>
            ))}
            {[["Main Headline","headline",true,""],["Location","location",false,"Based in USA"]].map(([label,key,req,ph])=>(
              <div key={key} className="col-span-2">
                <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">{label}</label>
                <input type="text" required={req} placeholder={ph} value={fields[key]} onChange={e=>setFields({...fields,[key]:e.target.value})}
                  className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:outline-none focus:ring-2 focus:ring-olivia-gold font-medium"/>
              </div>
            ))}
            <div className="col-span-2">
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Extended Bio</label>
              <textarea required rows={5} value={fields.bio} onChange={e=>setFields({...fields,bio:e.target.value})}
                className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:outline-none focus:ring-2 focus:ring-olivia-gold font-medium resize-none"/>
            </div>
            <div className="col-span-2">
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">CV / Resume URL <span className="text-gray-300 font-normal normal-case">(optional)</span></label>
              <input type="url" placeholder="https://your-cv.pdf" value={fields.cvUrl} onChange={e=>setFields({...fields,cvUrl:e.target.value})}
                className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:outline-none focus:ring-2 focus:ring-olivia-gold font-medium"/>
            </div>
          </div>
          <button type="submit" disabled={saving||uploading}
            className="bg-olivia-green text-white font-bold px-10 py-4 rounded-full hover:bg-olivia-gold hover:text-black shadow-lg transition-colors w-full sm:w-auto disabled:opacity-60 disabled:cursor-not-allowed">
            {saving?"Saving…":"Save Profile Details"}
          </button>
        </form>
      </div>
    </>
  );
};
export default AdminProfile;
'@

# ==============================================================
# 17. frontend/src/pages/admin/AdminServices.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminServices.jsx" @'
import { useState, useContext, useEffect } from "react";
import { PortfolioContext } from "../../context/PortfolioContext";
import { AuthContext }      from "../../context/AuthContext";

const Toast = ({msg,type}) => !msg ? null : (
  <div className={`fixed bottom-6 right-6 z-50 px-6 py-3 rounded-2xl border font-semibold text-sm shadow-xl ${type==="error"?"bg-red-50 text-red-700 border-red-200":"bg-green-50 text-green-700 border-green-200"}`}>{msg}</div>
);
const EMPTY = {title:"",description:"",icon:""};

const AdminServices = ({onSave}) => {
  const { profile, refreshData } = useContext(PortfolioContext);
  const { user } = useContext(AuthContext);
  const [view,idx,setIdx]   = [useState("list")[0],useState(null)[0],useState(null)[1]];
  const [setView]            = [useState("list")[1]];

  // Corrected state declarations
  const [viewState,  setViewState]  = useState("list");
  const [services,   setServices]   = useState([]);
  const [formData,   setFormData]   = useState(EMPTY);
  const [editingIdx, setEditingIdx] = useState(null);
  const [saving,     setSaving]     = useState(false);
  const [toast,      setToast]      = useState({msg:"",type:"success"});
  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast({msg:"",type:"success"}),3500); };

  useEffect(() => { if (profile?.services) setServices(profile.services); }, [profile]);

  const persist = async (updated) => {
    if (!user?.token) { showToast("Not authenticated","error"); return false; }
    setSaving(true);
    try {
      const res  = await fetch("http://localhost:5000/api/profile",{method:"PUT",headers:{"Content-Type":"application/json",Authorization:`Bearer ${user.token}`},body:JSON.stringify({services:updated})});
      const data = await res.json();
      if (res.ok) { refreshData?.(); onSave?.(); return true; }
      showToast(data.message||"Save failed","error"); return false;
    } catch { showToast("Network error","error"); return false; }
    finally { setSaving(false); }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    const updated = [...services];
    if (viewState==="edit"&&editingIdx!==null) updated[editingIdx]=formData; else updated.push(formData);
    const ok = await persist(updated);
    if (ok) { setServices(updated); showToast(viewState==="edit"?"Service updated ✓":"Service added ✓"); setViewState("list"); }
  };

  const handleDelete = async (i) => {
    if (!window.confirm("Delete this service?")) return;
    const updated = services.filter((_,idx)=>idx!==i);
    const ok = await persist(updated);
    if (ok) { setServices(updated); showToast("Service deleted"); }
  };

  if (viewState!=="list") return (
    <>
      <Toast {...toast}/>
      <div className="bg-white rounded-[32px] p-10 shadow-sm border border-gray-100 max-w-3xl">
        <div className="flex justify-between items-center mb-8 border-b pb-4">
          <h3 className="text-2xl font-serif font-bold text-olivia-green">{viewState==="add"?"Add New Service":"Edit Service"}</h3>
          <button onClick={()=>setViewState("list")} className="text-gray-500 hover:text-black font-bold text-sm bg-gray-100 px-4 py-2 rounded-lg">← Return to List</button>
        </div>
        <form onSubmit={handleSave} className="space-y-6">
          <div className="grid grid-cols-2 gap-8">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Service Title</label>
              <input required type="text" value={formData.title} onChange={e=>setFormData({...formData,title:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/>
            </div>
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Icon / Emoji</label>
              <input type="text" value={formData.icon} onChange={e=>setFormData({...formData,icon:e.target.value})} placeholder="e.g. 🎨 or ✦" className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/>
            </div>
            <div className="col-span-2">
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Description</label>
              <textarea required rows={4} value={formData.description} onChange={e=>setFormData({...formData,description:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium resize-none"/>
            </div>
          </div>
          <button type="submit" disabled={saving} className="bg-olivia-green text-white font-bold px-10 py-4 rounded-full hover:bg-olivia-gold hover:text-black shadow-lg transition-colors disabled:opacity-60">{saving?"Saving…":"Save Service"}</button>
        </form>
      </div>
    </>
  );

  return (
    <>
      <Toast {...toast}/>
      <div>
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-xl font-bold font-serif text-olivia-green">Configured Services ({services.length})</h2>
          <button onClick={()=>{setFormData(EMPTY);setEditingIdx(null);setViewState("add");}} className="bg-olivia-gold font-bold px-6 py-3 rounded-full hover:bg-yellow-500 shadow-md">+ Add New Service</button>
        </div>
        <div className="bg-white rounded-[32px] p-6 shadow-sm border border-gray-100">
          {services.length===0 ? <p className="text-center text-gray-400 py-10">No services yet.</p> :
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {services.map((s,i)=>(
                <div key={i} className="bg-gray-50 border border-gray-100 p-6 rounded-2xl hover:shadow-md transition-shadow">
                  <div className="w-12 h-12 bg-white rounded-xl shadow-sm border border-gray-100 flex items-center justify-center text-2xl mb-4">{s.icon||"✦"}</div>
                  <h4 className="font-bold text-lg mb-2">{s.title}</h4>
                  <p className="text-sm text-gray-500 mb-6 line-clamp-3">{s.description}</p>
                  <div className="flex gap-4 border-t pt-4 border-gray-200">
                    <button onClick={()=>{setFormData(s);setEditingIdx(i);setViewState("edit");}} className="text-sm font-bold text-olivia-green hover:underline">Edit</button>
                    <button onClick={()=>handleDelete(i)} className="text-sm font-bold text-red-500 hover:underline">Delete</button>
                  </div>
                </div>
              ))}
            </div>
          }
        </div>
      </div>
    </>
  );
};
export default AdminServices;
'@

# ==============================================================
# 18. frontend/src/pages/admin/AdminProjects.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminProjects.jsx" @'
import { useState, useEffect, useContext } from "react";
import { AuthContext }      from "../../context/AuthContext";
import { PortfolioContext } from "../../context/PortfolioContext";

const Toast = ({msg,type}) => !msg ? null : (
  <div className={`fixed bottom-6 right-6 z-50 px-6 py-3 rounded-2xl border font-semibold text-sm shadow-xl ${type==="error"?"bg-red-50 text-red-700 border-red-200":"bg-green-50 text-green-700 border-green-200"}`}>{msg}</div>
);
const EMPTY = {title:"",description:"",technologies:"",liveViewUrl:"",githubUrl:"",imageUrl:""};

const AdminProjects = ({onSave}) => {
  const { user } = useContext(AuthContext);
  const { refreshData } = useContext(PortfolioContext);
  const [projects,  setProjects]  = useState([]);
  const [view,      setView]      = useState("list");
  const [formData,  setFormData]  = useState(EMPTY);
  const [uploading, setUploading] = useState(false);
  const [saving,    setSaving]    = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [toast,     setToast]     = useState({msg:"",type:"success"});
  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast({msg:"",type:"success"}),3500); };
  const resolve = (url) => { if (!url) return null; if (url.startsWith("http")) return url; return `http://localhost:5000${url.startsWith("/")?"":"/"}${url}`; };

  const fetchProjects = async () => {
    try { const res=await fetch("http://localhost:5000/api/projects"); const data=await res.json(); setProjects(Array.isArray(data)?data:[]); } catch(e){ console.error(e); }
  };
  useEffect(()=>{ fetchProjects(); },[]);

  const handleImageUpload = async (e) => {
    const file=e.target.files[0]; if (!file) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    setUploading(true);
    const form=new FormData(); form.append("image",file);
    try {
      const res=await fetch("http://localhost:5000/api/upload",{method:"POST",headers:{Authorization:`Bearer ${user.token}`},body:form});
      const data=await res.json();
      if (res.ok) { setFormData(p=>({...p,imageUrl:data.url})); showToast("Image uploaded ✓"); }
      else showToast(data.message||"Upload failed","error");
    } catch { showToast("Upload error","error"); } finally { setUploading(false); }
  };

  const handleSave = async (e) => {
    e.preventDefault(); if (!user?.token) { showToast("Not authenticated","error"); return; }
    setSaving(true);
    const payload={...formData,technologies:Array.isArray(formData.technologies)?formData.technologies:formData.technologies.split(",").map(t=>t.trim()).filter(Boolean)};
    try {
      const url=view==="edit"?`http://localhost:5000/api/projects/${editingId}`:"http://localhost:5000/api/projects";
      const res=await fetch(url,{method:view==="edit"?"PUT":"POST",headers:{"Content-Type":"application/json",Authorization:`Bearer ${user.token}`},body:JSON.stringify(payload)});
      const data=await res.json();
      if (res.ok) { showToast(view==="edit"?"Project updated ✓":"Project added ✓"); setView("list"); fetchProjects(); refreshData?.(); onSave?.(); }
      else showToast(data.message||"Save failed","error");
    } catch { showToast("Network error","error"); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this project?")) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    try {
      await fetch(`http://localhost:5000/api/projects/${id}`,{method:"DELETE",headers:{Authorization:`Bearer ${user.token}`}});
      fetchProjects(); refreshData?.(); onSave?.(); showToast("Project deleted");
    } catch { showToast("Delete failed","error"); }
  };

  if (view!=="list") {
    const preview=resolve(formData.imageUrl);
    return (
      <>
        <Toast {...toast}/>
        <div className="bg-white rounded-[32px] p-10 shadow-sm border border-gray-100 max-w-4xl">
          <div className="flex justify-between items-center mb-8 border-b pb-4">
            <h3 className="text-2xl font-serif font-bold text-olivia-green">{view==="add"?"Add New Project":"Edit Project"}</h3>
            <button onClick={()=>setView("list")} className="text-gray-500 hover:text-black font-bold text-sm bg-gray-100 px-4 py-2 rounded-lg">← Return to List</button>
          </div>
          <form onSubmit={handleSave} className="space-y-6">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-3">Project Thumbnail</label>
              {preview&&<img src={preview} className="w-full max-w-sm h-48 object-cover rounded-xl mb-4 border shadow-sm" alt="preview"/>}
              <input type="file" accept="image/*" onChange={handleImageUpload} disabled={uploading} className="block w-full text-sm text-gray-500 file:mr-4 file:py-2.5 file:px-6 file:rounded-full file:border-0 file:text-sm file:font-bold file:bg-olivia-gold/10 file:text-olivia-green hover:file:bg-olivia-gold/20"/>
              {uploading&&<span className="text-xs text-olivia-gold font-bold mt-2 inline-block animate-pulse">Uploading…</span>}
            </div>
            <div className="grid grid-cols-2 gap-6">
              <div className="col-span-2"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Project Title</label><input required type="text" value={formData.title} onChange={e=>setFormData({...formData,title:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-2"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Technologies (comma separated)</label><input required type="text" placeholder="React, Node.js, MongoDB" value={Array.isArray(formData.technologies)?formData.technologies.join(", "):formData.technologies} onChange={e=>setFormData({...formData,technologies:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Live View URL</label><input type="url" placeholder="https://" value={formData.liveViewUrl} onChange={e=>setFormData({...formData,liveViewUrl:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">GitHub URL</label><input type="url" placeholder="https://github.com/..." value={formData.githubUrl} onChange={e=>setFormData({...formData,githubUrl:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-2"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Description</label><textarea required rows={5} value={formData.description} onChange={e=>setFormData({...formData,description:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium resize-none"/></div>
            </div>
            <button type="submit" disabled={saving||uploading} className="bg-olivia-green text-white font-bold px-10 py-4 rounded-full hover:bg-olivia-gold hover:text-black transition-colors shadow-md disabled:opacity-60">{saving?"Saving…":"Save Project"}</button>
          </form>
        </div>
      </>
    );
  }

  return (
    <>
      <Toast {...toast}/>
      <div>
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-xl font-bold font-serif text-olivia-green">Stored Projects ({projects.length})</h2>
          <button onClick={()=>{setFormData(EMPTY);setEditingId(null);setView("add");}} className="bg-olivia-gold font-bold px-6 py-3 rounded-full hover:bg-yellow-500 shadow-md">+ Add New Project</button>
        </div>
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[600px]">
            <thead><tr className="bg-olivia-green text-white">
              <th className="p-4 text-xs font-bold tracking-wider uppercase">Image</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase">Title</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase hidden md:table-cell">Tech</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase text-right">Actions</th>
            </tr></thead>
            <tbody>
              {projects.map(p=>{
                const src=resolve(p.imageUrl);
                return (
                  <tr key={p._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    <td className="p-4">{src?<img src={src} className="w-14 h-14 rounded-xl object-cover shadow-sm border border-gray-200" alt={p.title}/>:<div className="w-14 h-14 rounded-xl bg-gray-100 flex items-center justify-center text-gray-300 text-xs">No img</div>}</td>
                    <td className="p-4 font-bold text-olivia-text">{p.title}</td>
                    <td className="p-4 text-sm text-gray-500 hidden md:table-cell"><div className="flex gap-1 flex-wrap">{p.technologies?.slice(0,3).map((t,i)=><span key={i} className="bg-gray-100 px-2 py-1 rounded text-xs">{t}</span>)}{p.technologies?.length>3&&<span className="text-xs text-gray-400">+{p.technologies.length-3}</span>}</div></td>
                    <td className="p-4 text-right space-x-4 whitespace-nowrap">
                      <button onClick={()=>{setFormData({title:p.title||"",description:p.description||"",technologies:Array.isArray(p.technologies)?p.technologies.join(", "):"",liveViewUrl:p.liveViewUrl||"",githubUrl:p.githubUrl||"",imageUrl:p.imageUrl||""});setEditingId(p._id);setView("edit");}} className="text-sm font-bold text-olivia-green hover:underline">Edit</button>
                      <button onClick={()=>handleDelete(p._id)} className="text-sm font-bold text-red-500 hover:underline">Delete</button>
                    </td>
                  </tr>
                );
              })}
              {projects.length===0&&<tr><td colSpan="4" className="p-8 text-center text-gray-400 font-medium">No projects found. Click "+ Add New Project" to start.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
};
export default AdminProjects;
'@

# ==============================================================
# 19. frontend/src/pages/admin/AdminBlogs.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminBlogs.jsx" @'
import { useState, useEffect, useContext } from "react";
import { AuthContext }      from "../../context/AuthContext";
import { PortfolioContext } from "../../context/PortfolioContext";

const Toast = ({msg,type}) => !msg ? null : (
  <div className={`fixed bottom-6 right-6 z-50 px-6 py-3 rounded-2xl border font-semibold text-sm shadow-xl ${type==="error"?"bg-red-50 text-red-700 border-red-200":"bg-green-50 text-green-700 border-green-200"}`}>{msg}</div>
);
const CATS  = ["Design","Technology","Career","General News"];
const EMPTY = {title:"",content:"",imageUrl:"",category:"Design"};

const AdminBlogs = ({onSave}) => {
  const { user } = useContext(AuthContext);
  const { refreshData } = useContext(PortfolioContext);
  const [blogs,     setBlogs]     = useState([]);
  const [view,      setView]      = useState("list");
  const [formData,  setFormData]  = useState(EMPTY);
  const [uploading, setUploading] = useState(false);
  const [saving,    setSaving]    = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [toast,     setToast]     = useState({msg:"",type:"success"});
  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast({msg:"",type:"success"}),3500); };
  const resolve = (url) => { if (!url) return null; if (url.startsWith("http")) return url; return `http://localhost:5000${url.startsWith("/")?"":"/"}${url}`; };

  const fetchBlogs = async () => {
    try { const res=await fetch("http://localhost:5000/api/blogs"); const data=await res.json(); setBlogs(Array.isArray(data)?data:[]); } catch(e){ console.error(e); }
  };
  useEffect(()=>{ fetchBlogs(); },[]);

  const handleImageUpload = async (e) => {
    const file=e.target.files[0]; if (!file) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    setUploading(true);
    const form=new FormData(); form.append("image",file);
    try {
      const res=await fetch("http://localhost:5000/api/upload",{method:"POST",headers:{Authorization:`Bearer ${user.token}`},body:form});
      const data=await res.json();
      if (res.ok) { setFormData(p=>({...p,imageUrl:data.url})); showToast("Image uploaded ✓"); }
      else showToast(data.message||"Upload failed","error");
    } catch { showToast("Upload error","error"); } finally { setUploading(false); }
  };

  const handleSave = async (e) => {
    e.preventDefault(); if (!user?.token) { showToast("Not authenticated","error"); return; }
    setSaving(true);
    try {
      const url=view==="edit"?`http://localhost:5000/api/blogs/${editingId}`:"http://localhost:5000/api/blogs";
      const res=await fetch(url,{method:view==="edit"?"PUT":"POST",headers:{"Content-Type":"application/json",Authorization:`Bearer ${user.token}`},body:JSON.stringify(formData)});
      const data=await res.json();
      if (res.ok) { showToast(view==="edit"?"Blog updated ✓":"Blog published ✓"); setView("list"); fetchBlogs(); refreshData?.(); onSave?.(); }
      else showToast(data.message||"Save failed","error");
    } catch { showToast("Network error","error"); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this post?")) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    try { await fetch(`http://localhost:5000/api/blogs/${id}`,{method:"DELETE",headers:{Authorization:`Bearer ${user.token}`}}); fetchBlogs(); refreshData?.(); onSave?.(); showToast("Post deleted"); }
    catch { showToast("Delete failed","error"); }
  };

  if (view!=="list") {
    const preview=resolve(formData.imageUrl);
    return (
      <>
        <Toast {...toast}/>
        <div className="bg-white rounded-[32px] p-10 shadow-sm border border-gray-100 max-w-4xl">
          <div className="flex justify-between items-center mb-8 border-b pb-4">
            <h3 className="text-2xl font-serif font-bold text-olivia-green">{view==="add"?"Compose New Post":"Edit Post"}</h3>
            <button onClick={()=>setView("list")} className="text-gray-500 hover:text-black font-bold text-sm bg-gray-100 px-4 py-2 rounded-lg">← Back</button>
          </div>
          <form onSubmit={handleSave} className="space-y-6">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-3">Cover Image</label>
              {preview&&<img src={preview} className="w-full max-w-sm h-44 object-cover rounded-xl mb-4 border shadow-sm" alt="preview"/>}
              <input type="file" accept="image/*" onChange={handleImageUpload} disabled={uploading} className="block w-full text-sm text-gray-500 file:mr-4 file:py-2.5 file:px-6 file:rounded-full file:border-0 file:text-sm file:font-bold file:bg-olivia-gold/10 file:text-olivia-green hover:file:bg-olivia-gold/20"/>
              {uploading&&<span className="text-xs text-olivia-gold font-bold mt-2 inline-block animate-pulse">Uploading…</span>}
            </div>
            <div className="grid grid-cols-2 gap-6">
              <div><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Category</label><select value={formData.category} onChange={e=>setFormData({...formData,category:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium">{CATS.map(c=><option key={c}>{c}</option>)}</select></div>
              <div className="col-span-2"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Article Title</label><input required type="text" value={formData.title} onChange={e=>setFormData({...formData,title:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-2"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Content / Body</label><textarea required rows={8} value={formData.content} onChange={e=>setFormData({...formData,content:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium resize-none"/></div>
            </div>
            <button type="submit" disabled={saving||uploading} className="bg-olivia-green text-white font-bold px-10 py-4 rounded-full hover:bg-olivia-gold hover:text-black transition-colors shadow-md disabled:opacity-60">{saving?"Publishing…":"Publish Post"}</button>
          </form>
        </div>
      </>
    );
  }

  return (
    <>
      <Toast {...toast}/>
      <div>
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-xl font-bold font-serif text-olivia-green">Published Posts ({blogs.length})</h2>
          <button onClick={()=>{setFormData(EMPTY);setEditingId(null);setView("add");}} className="bg-olivia-gold font-bold px-6 py-3 rounded-full hover:bg-yellow-500 shadow-md">+ Draft New Article</button>
        </div>
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[500px]">
            <thead><tr className="bg-olivia-green text-white">
              <th className="p-4 text-xs font-bold tracking-wider uppercase">Cover</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase">Title</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase hidden md:table-cell">Date</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase text-right">Actions</th>
            </tr></thead>
            <tbody>
              {blogs.map(b=>{ const src=resolve(b.imageUrl); return (
                <tr key={b._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                  <td className="p-4">{src?<img src={src} className="w-16 h-12 rounded-lg object-cover shadow-sm border border-gray-200" alt={b.title}/>:<div className="w-16 h-12 rounded-lg bg-gray-100 flex items-center justify-center text-gray-300 text-xs">No img</div>}</td>
                  <td className="p-4 font-bold text-olivia-text">{b.title}<span className="block text-xs text-olivia-gold font-bold uppercase mt-0.5">{b.category}</span></td>
                  <td className="p-4 text-sm text-gray-500 hidden md:table-cell">{new Date(b.createdAt).toLocaleDateString()}</td>
                  <td className="p-4 text-right space-x-4 whitespace-nowrap">
                    <button onClick={()=>{setFormData({title:b.title||"",content:b.content||"",imageUrl:b.imageUrl||"",category:b.category||"Design"});setEditingId(b._id);setView("edit");}} className="text-sm font-bold text-olivia-green hover:underline">Edit</button>
                    <button onClick={()=>handleDelete(b._id)} className="text-sm font-bold text-red-500 hover:underline">Delete</button>
                  </td>
                </tr>
              );})}
              {blogs.length===0&&<tr><td colSpan="4" className="p-8 text-center text-gray-400 font-medium">No posts yet.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
};
export default AdminBlogs;
'@

# ==============================================================
# 20. frontend/src/pages/admin/AdminTestimonials.jsx
# ==============================================================
Write-File "frontend/src/pages/admin/AdminTestimonials.jsx" @'
import { useState, useEffect, useContext } from "react";
import { AuthContext }      from "../../context/AuthContext";
import { PortfolioContext } from "../../context/PortfolioContext";

const Toast = ({msg,type}) => !msg ? null : (
  <div className={`fixed bottom-6 right-6 z-50 px-6 py-3 rounded-2xl border font-semibold text-sm shadow-xl ${type==="error"?"bg-red-50 text-red-700 border-red-200":"bg-green-50 text-green-700 border-green-200"}`}>{msg}</div>
);
const Stars = ({n}) => <span className="text-olivia-gold text-sm">{"★".repeat(Math.min(Number(n)||0,5))}{"☆".repeat(Math.max(0,5-(Number(n)||0)))}</span>;
const EMPTY = {name:"",company:"",text:"",rating:5,imageUrl:""};

const AdminTestimonials = ({onSave}) => {
  const { user } = useContext(AuthContext);
  const { refreshData } = useContext(PortfolioContext);
  const [testimonials, setTestimonials] = useState([]);
  const [view,         setView]         = useState("list");
  const [formData,     setFormData]     = useState(EMPTY);
  const [uploading,    setUploading]    = useState(false);
  const [saving,       setSaving]       = useState(false);
  const [editingId,    setEditingId]    = useState(null);
  const [toast,        setToast]        = useState({msg:"",type:"success"});
  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast({msg:"",type:"success"}),3500); };
  const resolve = (url) => { if (!url) return null; if (url.startsWith("http")) return url; return `http://localhost:5000${url.startsWith("/")?"":"/"}${url}`; };

  const fetchTestimonials = async () => {
    try {
      const res=await fetch("http://localhost:5000/api/testimonials"); const data=await res.json();
      setTestimonials(Array.isArray(data)?data.map(t=>({...t,name:t.name||t.clientName||"",company:t.company||t.role||""})):[]);
    } catch(e){ console.error(e); }
  };
  useEffect(()=>{ fetchTestimonials(); },[]);

  const handleImageUpload = async (e) => {
    const file=e.target.files[0]; if (!file) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    setUploading(true);
    const form=new FormData(); form.append("image",file);
    try {
      const res=await fetch("http://localhost:5000/api/upload",{method:"POST",headers:{Authorization:`Bearer ${user.token}`},body:form});
      const data=await res.json();
      if (res.ok) { setFormData(p=>({...p,imageUrl:data.url})); showToast("Image uploaded ✓"); }
      else showToast(data.message||"Upload failed","error");
    } catch { showToast("Upload error","error"); } finally { setUploading(false); }
  };

  const handleSave = async (e) => {
    e.preventDefault(); if (!user?.token) { showToast("Not authenticated","error"); return; }
    setSaving(true);
    const payload={...formData,clientName:formData.name,role:formData.company};
    try {
      const url=view==="edit"?`http://localhost:5000/api/testimonials/${editingId}`:"http://localhost:5000/api/testimonials";
      const res=await fetch(url,{method:view==="edit"?"PUT":"POST",headers:{"Content-Type":"application/json",Authorization:`Bearer ${user.token}`},body:JSON.stringify(payload)});
      const data=await res.json();
      if (res.ok) { showToast(view==="edit"?"Testimonial updated ✓":"Testimonial added ✓"); setView("list"); fetchTestimonials(); refreshData?.(); onSave?.(); }
      else showToast(data.message||"Save failed","error");
    } catch { showToast("Network error","error"); } finally { setSaving(false); }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this testimonial?")) return;
    if (!user?.token) { showToast("Not authenticated","error"); return; }
    try { await fetch(`http://localhost:5000/api/testimonials/${id}`,{method:"DELETE",headers:{Authorization:`Bearer ${user.token}`}}); fetchTestimonials(); refreshData?.(); onSave?.(); showToast("Testimonial deleted"); }
    catch { showToast("Delete failed","error"); }
  };

  if (view!=="list") {
    const preview=resolve(formData.imageUrl);
    return (
      <>
        <Toast {...toast}/>
        <div className="bg-white rounded-[32px] p-10 shadow-sm border border-gray-100 max-w-4xl">
          <div className="flex justify-between items-center mb-8 border-b pb-4">
            <h3 className="text-2xl font-serif font-bold text-olivia-green">{view==="add"?"Add Testimonial":"Edit Testimonial"}</h3>
            <button onClick={()=>setView("list")} className="text-gray-500 hover:text-black font-bold text-sm bg-gray-100 px-4 py-2 rounded-lg">← Back</button>
          </div>
          <form onSubmit={handleSave} className="space-y-6">
            <div className="flex items-center gap-6 border-b pb-6">
              <div className="w-24 h-24 rounded-full bg-gray-100 border-4 border-gray-50 overflow-hidden shrink-0 flex items-center justify-center">
                {preview?<img src={preview} className="w-full h-full object-cover" alt="avatar"/>:<span className="text-4xl text-gray-300">👤</span>}
              </div>
              <div className="flex-1">
                <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Client Avatar</label>
                <input type="file" accept="image/*" onChange={handleImageUpload} disabled={uploading} className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-bold file:bg-gray-100 file:text-gray-700 hover:file:bg-gray-200"/>
                {uploading&&<span className="text-xs text-olivia-gold font-bold mt-2 inline-block animate-pulse">Uploading…</span>}
              </div>
            </div>
            <div className="grid grid-cols-3 gap-6">
              <div className="col-span-3 md:col-span-1"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Client Name</label><input required type="text" value={formData.name} onChange={e=>setFormData({...formData,name:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-3 md:col-span-1"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Company / Role</label><input required type="text" value={formData.company} onChange={e=>setFormData({...formData,company:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-3 md:col-span-1"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Rating <Stars n={formData.rating}/></label><input required type="number" min="1" max="5" value={formData.rating} onChange={e=>setFormData({...formData,rating:Number(e.target.value)})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium"/></div>
              <div className="col-span-3"><label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Testimonial Quote</label><textarea required rows={4} value={formData.text} onChange={e=>setFormData({...formData,text:e.target.value})} className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl focus:ring-2 focus:ring-olivia-gold font-medium resize-none"/></div>
            </div>
            <button type="submit" disabled={saving||uploading} className="bg-olivia-green text-white font-bold px-10 py-4 rounded-full hover:bg-olivia-gold hover:text-black transition-colors shadow-md disabled:opacity-60">{saving?"Saving…":"Save Review"}</button>
          </form>
        </div>
      </>
    );
  }

  return (
    <>
      <Toast {...toast}/>
      <div>
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-xl font-bold font-serif text-olivia-green">Stored Testimonials ({testimonials.length})</h2>
          <button onClick={()=>{setFormData(EMPTY);setEditingId(null);setView("add");}} className="bg-olivia-gold font-bold px-6 py-3 rounded-full hover:bg-yellow-500 shadow-md">+ Add New Testimonial</button>
        </div>
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[500px]">
            <thead><tr className="bg-olivia-green text-white">
              <th className="p-4 text-xs font-bold tracking-wider uppercase">Client</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase hidden md:table-cell">Review</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase hidden md:table-cell">Rating</th>
              <th className="p-4 text-xs font-bold tracking-wider uppercase text-right">Actions</th>
            </tr></thead>
            <tbody>
              {testimonials.map(t=>{ const src=resolve(t.imageUrl); return (
                <tr key={t._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                  <td className="p-4"><div className="flex items-center gap-4">{src?<img src={src} className="w-12 h-12 rounded-full object-cover shadow-sm border border-gray-200 shrink-0" alt={t.name}/>:<div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center text-gray-300 shrink-0">👤</div>}<div><p className="font-bold text-olivia-text">{t.name||t.clientName}</p><p className="text-xs text-olivia-gold font-bold uppercase">{t.company||t.role}</p></div></div></td>
                  <td className="p-4 text-sm text-gray-500 hidden md:table-cell max-w-xs"><p className="truncate">{t.text}</p></td>
                  <td className="p-4 hidden md:table-cell"><Stars n={t.rating}/></td>
                  <td className="p-4 text-right space-x-4 whitespace-nowrap">
                    <button onClick={()=>{setFormData({name:t.name||t.clientName||"",company:t.company||t.role||"",text:t.text||"",rating:t.rating||5,imageUrl:t.imageUrl||""});setEditingId(t._id);setView("edit");}} className="text-sm font-bold text-olivia-green hover:underline">Edit</button>
                    <button onClick={()=>handleDelete(t._id)} className="text-sm font-bold text-red-500 hover:underline">Delete</button>
                  </td>
                </tr>
              );})}
              {testimonials.length===0&&<tr><td colSpan="4" className="p-8 text-center text-gray-400 font-medium">No testimonials yet.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
};
export default AdminTestimonials;
'@

Write-Host ""
Write-Host "ALL DONE! All 20 files replaced." -ForegroundColor Cyan
Write-Host ""
Write-Host "Now restart your servers:" -ForegroundColor Yellow
Write-Host "  Terminal 1:  cd backend  && npm run dev" -ForegroundColor White
Write-Host "  Terminal 2:  cd frontend && npm run dev" -ForegroundColor White