/**
 * Gurlal Sohal Raider Portfolio - Supabase Cloud Database Client
 * Centralized, Secure Integration for Booking Enquiries, Live KPIs & Admin Sync
 */

(function (window) {
  'use strict';

  const SUPABASE_URL = 'https://qhdjjydjxeksiyrdiwrc.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_Vx_-XInEw7GaMgVN0fE-cA_wkjA0zun';
  const SESSION_STORAGE_KEY = 'gs_supabase_admin_session';

  const DEFAULT_KPIS = {
    exp: '16+ Years',
    tours: '15 Tours',
    scorpio: 'Scorpio-N',
    frandipur: '18 / 18',
    bullets: '10 Bullets',
    bikes: '45+ Bikes',
    raidingSide: 'Right Raider (Speed Baulk & Corner Specialist)',
    signatureMoves: 'Jump Escape, Touch, Body Swerve, Rapid Toe Touch'
  };

  const DEFAULT_TOURS = [
    { code: 'canada', country: 'Canada', flag: '🇨🇦', count: 9, club: 'Young Sports Club BC' },
    { code: 'usa', country: 'United States', flag: '🇺🇸', count: 2, club: 'North American Kabaddi Federation' },
    { code: 'australia', country: 'Australia', flag: '🇦🇺', count: 2, club: 'Australia Kabaddi Cup' },
    { code: 'malaysia', country: 'Malaysia', flag: '🇲🇾', count: 1, club: 'Kuala Lumpur International Cup' },
    { code: 'europe', country: 'Europe', flag: '🇪🇺', count: 1, club: 'European Kabaddi Championship Circuit' }
  ];

  const SupabaseService = {
    url: SUPABASE_URL,
    key: SUPABASE_KEY,

    getHeaders(withAuth = false) {
      const headers = {
        'apikey': this.key,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      };

      if (withAuth) {
        const session = this.getAdminSession();
        if (session && session.access_token) {
          headers['Authorization'] = `Bearer ${session.access_token}`;
        }
      }
      return headers;
    },

    /**
     * Admin Sign In via Supabase Auth (Email + Password) + RBAC Verification
     */
    async adminSignIn(email, password) {
      try {
        const resp = await fetch(`${this.url}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: {
            'apikey': this.key,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            email: (email || '').trim(),
            password: password || ''
          })
        });

        const data = await resp.json();
        if (resp.ok && data.access_token) {
          const session = {
            access_token: data.access_token,
            refresh_token: data.refresh_token,
            expires_at: Date.now() + (data.expires_in * 1000),
            user: data.user
          };

          // Strict Administrator Authorization Check against public.admin_users
          const authCheck = await this.verifyAdminRole(session.access_token, data.user ? data.user.id : null);
          if (!authCheck.isAuthorized) {
            this.adminSignOut();
            return {
              success: false,
              error: 'Access Denied: Your account is authenticated, but you are not registered as an authorized administrator in the management database.'
            };
          }

          session.role = authCheck.role || 'admin';
          session.pendingSchema = authCheck.pendingSchema || false;
          sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
          return { success: true, session };
        } else {
          return {
            success: false,
            error: data.error_description || data.msg || data.message || 'Invalid email or password.'
          };
        }
      } catch (err) {
        return { success: false, error: err.message || 'Network error connecting to authentication server.' };
      }
    },

    /**
     * Verify Administrator Authorization against public.admin_users
     */
    async verifyAdminRole(accessToken, userId) {
      if (!accessToken) return { isAuthorized: false };
      try {
        const filter = userId ? `?user_id=eq.${encodeURIComponent(userId)}&select=role` : '?select=role';
        const resp = await fetch(`${this.url}/rest/v1/admin_users${filter}`, {
          method: 'GET',
          headers: {
            'apikey': this.key,
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
          }
        });

        if (resp.ok) {
          const rows = await resp.json();
          if (Array.isArray(rows) && rows.length > 0) {
            return { isAuthorized: true, role: rows[0].role };
          }
          return { isAuthorized: false, reason: 'not_in_admin_table' };
        } else if (resp.status === 404) {
          // admin_users table pending migration execution; grant bootstrap session
          console.warn('public.admin_users table not provisioned yet; execute schema.sql in Supabase to lock RBAC.');
          return { isAuthorized: true, role: 'bootstrap_admin', pendingSchema: true };
        }
      } catch (e) {
        console.error('Error verifying admin authorization:', e);
      }
      return { isAuthorized: false };
    },

    /**
     * Refresh Admin Session Token via Supabase Auth
     */
    async adminRefreshToken(refreshToken) {
      if (!refreshToken) return null;
      try {
        const resp = await fetch(`${this.url}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: {
            'apikey': this.key,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ refresh_token: refreshToken })
        });
        const data = await resp.json();
        if (resp.ok && data.access_token) {
          const session = {
            access_token: data.access_token,
            refresh_token: data.refresh_token || refreshToken,
            expires_at: Date.now() + (data.expires_in * 1000),
            user: data.user
          };
          sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
          return session;
        }
      } catch (e) {}
      return null;
    },

    /**
     * Admin Sign Out
     */
    adminSignOut() {
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
      sessionStorage.removeItem('gs_admin_session');
    },

    /**
     * Get Current Admin Session
     */
    getAdminSession() {
      try {
        const raw = sessionStorage.getItem(SESSION_STORAGE_KEY);
        if (!raw) return null;
        const s = JSON.parse(raw);
        if (s && s.access_token) {
          if (s.expires_at && s.expires_at < Date.now()) {
            if (s.refresh_token) {
              this.adminRefreshToken(s.refresh_token);
            } else {
              this.adminSignOut();
              return null;
            }
          }
          return s;
        }
      } catch (e) {}
      return null;
    },

    isAdminAuthenticated() {
      return this.getAdminSession() !== null;
    },

    /**
     * Submit a new enquiry to Supabase public table
     */
    async submitEnquiry(data) {
      const payload = {
        organizer_name: (data.organizerName || '').trim(),
        phone: (data.contactPhone || '').trim(),
        category: (data.enquiryCategory || data.category || 'Tournament Booking').trim(),
        dates_location: (data.tournamentDates || data.datesLocation || '').trim(),
        message: (data.messageTerms || data.message || '').trim(),
        status: 'new'
      };

      let supabaseSuccess = false;
      let record = null;
      let errorMessage = null;

      try {
        const headers = Object.assign({}, this.getHeaders(false), { 'Prefer': 'return=minimal' });
        const resp = await fetch(`${this.url}/rest/v1/enquiries`, {
          method: 'POST',
          headers: headers,
          body: JSON.stringify(payload)
        });

        if (resp.ok || resp.status === 201) {
          supabaseSuccess = true;
          try {
            const resJson = await resp.json();
            record = resJson && resJson.length ? resJson[0] : null;
          } catch(e) {
            record = { id: 'ENQ-' + Date.now(), created_at: new Date().toISOString() };
          }
        } else {
          const errText = await resp.text();
          try {
            const errJson = JSON.parse(errText);
            errorMessage = errJson.message || errText;
          } catch(e) {
            errorMessage = errText;
          }
        }
      } catch (err) {
        errorMessage = err.message || 'Network error connecting to Supabase database.';
      }

      return {
        success: supabaseSuccess,
        error: errorMessage,
        record
      };
    },

    /**
     * Fetch all enquiries (Uses Bearer token if logged in)
     */
    async getEnquiries() {
      const isAuth = this.isAdminAuthenticated();
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?select=*&order=created_at.desc`, {
          method: 'GET',
          headers: this.getHeaders(isAuth)
        });

        if (resp.ok) {
          const rows = await resp.json();
          if (Array.isArray(rows)) {
            const mapped = rows.map(r => ({
              id: r.id,
              date: r.created_at,
              organizerName: r.organizer_name,
              contactPhone: r.phone,
              enquiryCategory: r.category,
              tournamentDates: r.dates_location,
              messageTerms: r.message,
              status: r.status || 'new',
              isSynced: true
            }));

            return { enquiries: mapped, source: 'supabase' };
          }
        }
      } catch (err) {}

      return { enquiries: [], source: 'empty' };
    },

    /**
     * Update enquiry status
     */
    async updateStatus(id, newStatus) {
      let remoteSuccess = false;
      const isAuth = this.isAdminAuthenticated();
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH',
          headers: this.getHeaders(isAuth),
          body: JSON.stringify({ status: newStatus })
        });
        if (resp.ok) remoteSuccess = true;
      } catch (err) {}

      return remoteSuccess;
    },

    /**
     * Delete an enquiry
     */
    async deleteEnquiry(id) {
      let remoteSuccess = false;
      const isAuth = this.isAdminAuthenticated();
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: this.getHeaders(isAuth)
        });
        if (resp.ok) remoteSuccess = true;
      } catch (err) {}

      return remoteSuccess;
    },

    /**
     * Fetch Scouting Metrics & KPIs (Supabase with Local Cache)
     */
    async getScoutingMetrics() {
      try {
        const resp = await fetch(`${this.url}/rest/v1/scouting_metrics?id=eq.current&select=*`, {
          method: 'GET',
          headers: this.getHeaders(false)
        });

        if (resp.ok) {
          const rows = await resp.json();
          if (rows && rows.length > 0) {
            const r = rows[0];
            const metrics = {
              exp: r.exp || DEFAULT_KPIS.exp,
              tours: r.tours || DEFAULT_KPIS.tours,
              scorpio: r.scorpio || DEFAULT_KPIS.scorpio,
              frandipur: r.frandipur || DEFAULT_KPIS.frandipur,
              bullets: r.bullets || DEFAULT_KPIS.bullets,
              bikes: r.bikes || DEFAULT_KPIS.bikes,
              raidingSide: r.raiding_side || DEFAULT_KPIS.raidingSide,
              signatureMoves: r.signature_moves || DEFAULT_KPIS.signatureMoves
            };
            localStorage.setItem('gurlal_scouting_metrics', JSON.stringify(metrics));
            return { metrics, source: 'supabase' };
          }
        }
      } catch (e) {}

      // Fallback to local storage or defaults
      try {
        const saved = localStorage.getItem('gurlal_scouting_metrics');
        if (saved) {
          return { metrics: Object.assign({}, DEFAULT_KPIS, JSON.parse(saved)), source: 'local' };
        }
      } catch (e) {}

      return { metrics: DEFAULT_KPIS, source: 'defaults' };
    },

    /**
     * Save Scouting Metrics & KPIs (Protected: Admin Auth Required)
     */
    async saveScoutingMetrics(kpis) {
      const isAuth = this.isAdminAuthenticated();
      const payload = {
        id: 'current',
        exp: kpis.exp || DEFAULT_KPIS.exp,
        tours: kpis.tours || DEFAULT_KPIS.tours,
        scorpio: kpis.scorpio || DEFAULT_KPIS.scorpio,
        frandipur: kpis.frandipur || DEFAULT_KPIS.frandipur,
        bullets: kpis.bullets || DEFAULT_KPIS.bullets,
        bikes: kpis.bikes || DEFAULT_KPIS.bikes,
        raiding_side: kpis.raidingSide || DEFAULT_KPIS.raidingSide,
        signature_moves: kpis.signatureMoves || DEFAULT_KPIS.signatureMoves,
        updated_at: new Date().toISOString()
      };

      // Always save to local cache for immediate feedback
      localStorage.setItem('gurlal_scouting_metrics', JSON.stringify({
        exp: payload.exp,
        tours: payload.tours,
        scorpio: payload.scorpio,
        frandipur: payload.frandipur,
        bullets: payload.bullets,
        bikes: payload.bikes,
        raidingSide: payload.raiding_side,
        signatureMoves: payload.signature_moves
      }));

      if (!isAuth) {
        return {
          success: false,
          error: 'Unauthorized. Please log in with Supabase admin credentials.'
        };
      }

      try {
        const resp = await fetch(`${this.url}/rest/v1/scouting_metrics?id=eq.current`, {
          method: 'PATCH',
          headers: this.getHeaders(true),
          body: JSON.stringify(payload)
        });

        if (resp.ok) {
          return {
            success: true,
            source: 'supabase',
            message: 'Scouting metrics saved successfully to Supabase database.'
          };
        } else {
          const errText = await resp.text();
          return {
            success: false,
            error: 'Database update failed: ' + errText
          };
        }
      } catch (e) {
        return {
          success: false,
          error: 'Network error connecting to Supabase database: ' + (e.message || e)
        };
      }
    },

    /**
     * Apply live metrics to all elements with matching classes on any page
     */
    applyScoutingMetricsToDOM(metrics) {
      if (!metrics) return;
      document.querySelectorAll('.kpi-exp-val').forEach(el => el.textContent = metrics.exp || DEFAULT_KPIS.exp);
      document.querySelectorAll('.kpi-tours-val').forEach(el => el.textContent = metrics.tours || DEFAULT_KPIS.tours);
      document.querySelectorAll('.kpi-scorpio-val').forEach(el => el.textContent = metrics.scorpio || DEFAULT_KPIS.scorpio);
      document.querySelectorAll('.kpi-frandipur-val').forEach(el => el.textContent = metrics.frandipur || DEFAULT_KPIS.frandipur);
      document.querySelectorAll('.kpi-bullets-val').forEach(el => el.textContent = metrics.bullets || DEFAULT_KPIS.bullets);
      document.querySelectorAll('.kpi-bikes-val').forEach(el => el.textContent = metrics.bikes || DEFAULT_KPIS.bikes);
      document.querySelectorAll('.profile-raiding-side').forEach(el => el.innerHTML = metrics.raidingSide || DEFAULT_KPIS.raidingSide);
      document.querySelectorAll('.profile-signature-moves').forEach(el => el.innerHTML = metrics.signatureMoves || DEFAULT_KPIS.signatureMoves);
    },

    /**
     * Global Init for Public Pages: Fetches live data and applies to DOM
     */
    async initPageSync() {
      // 1. Apply cached metrics immediately to avoid layout shift
      try {
        const cached = localStorage.getItem('gurlal_scouting_metrics');
        if (cached) {
          this.applyScoutingMetricsToDOM(JSON.parse(cached));
        } else {
          this.applyScoutingMetricsToDOM(DEFAULT_KPIS);
        }
      } catch (e) {
        this.applyScoutingMetricsToDOM(DEFAULT_KPIS);
      }

      // 2. Refresh from Supabase in background
      try {
        const { metrics } = await this.getScoutingMetrics();
        if (metrics) {
          this.applyScoutingMetricsToDOM(metrics);
        }
      } catch (e) {}
    },

    getToursBreakdown() {
      return DEFAULT_TOURS;
    }
  };

  window.GurlalSupabase = SupabaseService;
})(window);
