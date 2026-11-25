/**
 * Gurlal Sohal Raider Portfolio - Supabase Cloud Database Client
 * Official Integration for Booking Enquiries & Live Admin Sync
 */

(function (window) {
  'use strict';

  const SUPABASE_URL = 'https://qhdjjydjxeksiyrdiwrc.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_Vx_-XInEw7GaMgVN0fE-cA_wkjA0zun';
  const SESSION_STORAGE_KEY = 'gs_supabase_admin_session';

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
     * Admin Sign In via Supabase Auth (Email + Password)
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
          // Check expiration
          if (s.expires_at && s.expires_at < Date.now()) {
            this.adminSignOut();
            return null;
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
     * Submit a new enquiry to Supabase public table (with local fallback)
     */
    async submitEnquiry(data) {
      const payload = {
        organizer_name: (data.organizerName || '').trim(),
        phone: (data.contactPhone || '').trim(),
        category: (data.enquiryCategory || '').trim(),
        dates_location: (data.tournamentDates || '').trim(),
        message: (data.messageTerms || '').trim(),
        status: 'new'
      };

      let supabaseSuccess = false;
      let record = null;
      let errorMessage = null;

      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries`, {
          method: 'POST',
          headers: this.getHeaders(false),
          body: JSON.stringify(payload)
        });

        if (resp.ok) {
          const resJson = await resp.json();
          record = resJson && resJson.length ? resJson[0] : null;
          supabaseSuccess = true;
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
        errorMessage = err.message || 'Network error';
      }

      // Always save locally as fallback resilience
      try {
        const localEnquiry = {
          id: record ? record.id : ('ENQ-' + Date.now()),
          date: record ? record.created_at : new Date().toISOString(),
          organizerName: payload.organizer_name,
          contactPhone: payload.phone,
          enquiryCategory: payload.category,
          tournamentDates: payload.dates_location,
          messageTerms: payload.message,
          status: 'new',
          isSynced: supabaseSuccess
        };

        const existing = JSON.parse(localStorage.getItem('gs_raider_inquiries') || '[]');
        existing.unshift(localEnquiry);
        localStorage.setItem('gs_raider_inquiries', JSON.stringify(existing));
      } catch (e) {}

      return {
        success: supabaseSuccess,
        error: errorMessage,
        record
      };
    },

    /**
     * Fetch all enquiries (Protected: uses Bearer token if logged in)
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

            localStorage.setItem('gs_raider_inquiries', JSON.stringify(mapped));
            return { enquiries: mapped, source: 'supabase' };
          }
        }
      } catch (err) {}

      // Fallback to local storage
      try {
        const local = JSON.parse(localStorage.getItem('gs_raider_inquiries') || '[]');
        return { enquiries: local, source: 'local' };
      } catch (e) {
        return { enquiries: [], source: 'empty' };
      }
    },

    /**
     * Update enquiry status (Protected)
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

      try {
        const list = JSON.parse(localStorage.getItem('gs_raider_inquiries') || '[]');
        const idx = list.findIndex(x => String(x.id) === String(id));
        if (idx !== -1) {
          list[idx].status = newStatus;
          localStorage.setItem('gs_raider_inquiries', JSON.stringify(list));
        }
      } catch (e) {}

      return remoteSuccess;
    },

    /**
     * Delete an enquiry (Protected)
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

      try {
        let list = JSON.parse(localStorage.getItem('gs_raider_inquiries') || '[]');
        list = list.filter(x => String(x.id) !== String(id));
        localStorage.setItem('gs_raider_inquiries', JSON.stringify(list));
      } catch (e) {}

      return remoteSuccess;
    }
  };

  window.GurlalSupabase = SupabaseService;
})(window);
