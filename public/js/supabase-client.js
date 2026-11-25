/**
 * Gurlal Sohal Raider Portfolio - Supabase Cloud Database Client
 * Official Integration for Booking Enquiries & Live Admin Sync
 */

(function (window) {
  'use strict';

  const SUPABASE_URL = 'https://qhdjjydjxeksiyrdiwrc.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_Vx_-XInEw7GaMgVN0fE-cA_wkjA0zun';

  const SupabaseService = {
    url: SUPABASE_URL,
    key: SUPABASE_KEY,

    getHeaders() {
      return {
        'apikey': this.key,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      };
    },

    /**
     * Submit a new enquiry to Supabase and fallback to localStorage
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

      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries`, {
          method: 'POST',
          headers: this.getHeaders(),
          body: JSON.stringify(payload)
        });

        if (resp.ok) {
          const resJson = await resp.json();
          record = resJson && resJson.length ? resJson[0] : null;
          supabaseSuccess = true;
          console.log('[Supabase] Enquiry saved to cloud:', record);
        } else {
          console.warn('[Supabase] HTTP Error submitting enquiry:', resp.status, await resp.text());
        }
      } catch (err) {
        console.warn('[Supabase] Network error submitting enquiry, using local backup:', err);
      }

      // Always save locally as well for offline resilience
      try {
        const localEnquiry = {
          id: record ? record.id : ('local_' + Date.now()),
          submittedAt: record ? record.created_at : new Date().toISOString(),
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
      } catch (e) {
        console.error('[Storage] Error saving local backup:', e);
      }

      return { success: true, supabaseSynced: supabaseSuccess, record };
    },

    /**
     * Fetch all enquiries (Supabase cloud first, localStorage fallback)
     */
    async getEnquiries() {
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?select=*&order=created_at.desc`, {
          method: 'GET',
          headers: {
            'apikey': this.key
          }
        });

        if (resp.ok) {
          const rows = await resp.json();
          if (Array.isArray(rows)) {
            // Map to client format
            const mapped = rows.map(r => ({
              id: r.id,
              submittedAt: r.created_at,
              organizerName: r.organizer_name,
              contactPhone: r.phone,
              enquiryCategory: r.category,
              tournamentDates: r.dates_location,
              messageTerms: r.message,
              status: r.status || 'new',
              isSynced: true
            }));

            // Sync down to localStorage for fast access
            localStorage.setItem('gs_raider_inquiries', JSON.stringify(mapped));
            return { enquiries: mapped, source: 'supabase' };
          }
        }
      } catch (err) {
        console.warn('[Supabase] Could not fetch remote enquiries, falling back to local storage:', err);
      }

      // Fallback to local storage
      try {
        const local = JSON.parse(localStorage.getItem('gs_raider_inquiries') || '[]');
        return { enquiries: local, source: 'local' };
      } catch (e) {
        return { enquiries: [], source: 'empty' };
      }
    },

    /**
     * Update enquiry status
     */
    async updateStatus(id, newStatus) {
      let remoteSuccess = false;
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH',
          headers: this.getHeaders(),
          body: JSON.stringify({ status: newStatus })
        });
        if (resp.ok) remoteSuccess = true;
      } catch (err) {
        console.warn('[Supabase] Failed to update remote status:', err);
      }

      // Update local copy
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
     * Delete an enquiry
     */
    async deleteEnquiry(id) {
      let remoteSuccess = false;
      try {
        const resp = await fetch(`${this.url}/rest/v1/enquiries?id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: this.getHeaders()
        });
        if (resp.ok) remoteSuccess = true;
      } catch (err) {
        console.warn('[Supabase] Failed to delete remote enquiry:', err);
      }

      // Delete from local
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
