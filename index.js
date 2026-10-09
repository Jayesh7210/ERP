require('dotenv').config();
const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const { supabaseAdmin: supabase } = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5000;

// Simple Logger Middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Helper for Mock DB when Supabase is not reachable or tables not created
let isSupabaseConfigured = false;

// Health check and auto-create receipts storage bucket if live
async function initSupabase() {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
    try {
      const { data, error } = await supabase.from('users').select('id').limit(1);
      if (!error) {
        isSupabaseConfigured = true;
        console.log('✅ Connected to live Supabase database successfully.');
        supabase.storage.createBucket('receipts', { public: true }).then(({ error: bError }) => {
          if (bError && !bError.message.includes('already exists')) {
            console.warn('Notice on receipts storage bucket:', bError.message);
          } else {
            console.log('Supabase "receipts" bucket ready.');
          }
        }).catch(bErr => console.warn('Supabase storage unavailable:', bErr.message));
        return;
      } else {
        console.warn(`⚠️ Supabase returned an error (${error.message}). Operating in standalone in-memory mode.`);
      }
    } catch (err) {
      console.warn(`⚠️ Supabase unreachable (${err.message}). Operating in standalone in-memory mode.`);
    }
  } else {
    console.log('ℹ️ Supabase environment variables not set. Operating in standalone in-memory mode.');
  }
}
initSupabase();

// Mock Data Store for fallback/testing
const mockDb = {
  warehouses: [
    { id: 'w1', name: 'Main Central Warehouse', location: 'Mumbai' },
    { id: 'w2', name: 'Secondary Hub', location: 'Pune' }
  ],
  users: [
    { id: '804969de-a546-4e60-8137-c4d914563536', name: 'Super Admin', email: 'admin@erp.com', phone: '+91 99999 00001', role: 'super_admin', status: 'approved', warehouse_id: null, parent_id: null, is_on_duty: true, password: 'admin123', aadhaar_number: '5489 1234 8901', aadhaar_doc: 'Aadhaar_SuperAdmin.pdf', kyc_status: 'Verified', requires_password_setup: false },
    { id: 'u1', name: 'Super Admin', email: 'admin@erp.com', phone: '+91 99999 00001', role: 'super_admin', status: 'approved', warehouse_id: null, parent_id: null, is_on_duty: true, password: 'admin123', aadhaar_number: '5489 1234 8901', aadhaar_doc: 'Aadhaar_SuperAdmin.pdf', kyc_status: 'Verified', requires_password_setup: false },
    { id: 'b2345678-cd12-34ef-56df-7890abcdef12', name: 'Store Admin One', email: 'store@erp.com', phone: '+91 98765 10001', role: 'store_admin', status: 'approved', warehouse_id: 'w1', parent_id: null, is_on_duty: true, password: 'store123', aadhaar_number: '6321 9845 1024', aadhaar_doc: 'Aadhaar_StoreAdmin_One.pdf', kyc_status: 'Verified', requires_password_setup: false },
    { id: 'c3456789-de23-45ff-67ff-8901abcdef23', name: 'FSM Alpha', email: 'fsm@erp.com', phone: '+91 98765 10002', role: 'field_sales_manager', status: 'approved', warehouse_id: 'w1', parent_id: 'b2345678-cd12-34ef-56df-7890abcdef12', is_on_duty: true, password: 'fsm123', aadhaar_number: '7823 4512 9031', aadhaar_doc: 'Aadhaar_FSM_Alpha.pdf', kyc_status: 'Verified', requires_password_setup: false },
    // Salesman A (First salesman)
    { id: 'd4567890-ef34-56ff-78ff-9012abcdef34', name: 'Salesman John (A)', email: 'sales@erp.com', phone: '+91 98765 20001', role: 'salesman', status: 'approved', warehouse_id: 'w1', parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23', referrer_id: null, is_on_duty: true, password: 'sales123', aadhaar_number: '8921 7845 2314', aadhaar_doc: 'Aadhaar_Salesman_John.pdf', kyc_status: 'Verified', requires_password_setup: false },
    // Salesman B (Referred by A)
    { id: 'b0000000-0000-0000-0000-000000000002', name: 'Salesman Bharat (B)', email: 'sales_b@erp.com', phone: '+91 98765 20002', role: 'salesman', status: 'approved', warehouse_id: 'w1', parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23', referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34', is_on_duty: true, password: 'sales123', aadhaar_number: '9012 3456 7812', aadhaar_doc: 'Aadhaar_Bharat.pdf', kyc_status: 'Verified', requires_password_setup: false },
    // Salesman C (Referred by B)
    { id: 'c0000000-0000-0000-0000-000000000003', name: 'Salesman Chirag (C)', email: 'sales_c@erp.com', phone: '+91 98765 20003', role: 'salesman', status: 'approved', warehouse_id: 'w1', parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23', referrer_id: 'b0000000-0000-0000-0000-000000000002', is_on_duty: true, password: 'sales123', aadhaar_number: '3456 7890 1234', aadhaar_doc: 'Aadhaar_Chirag.pdf', kyc_status: 'Verified', requires_password_setup: false },
    // Salesman D (Referred by A)
    { id: 'd0000000-0000-0000-0000-000000000004', name: 'Salesman Deepak (D)', email: 'sales_d@erp.com', phone: '+91 98765 20004', role: 'salesman', status: 'approved', warehouse_id: 'w1', parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23', referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34', is_on_duty: true, password: 'sales123', aadhaar_number: '7890 1234 5678', aadhaar_doc: 'Aadhaar_Deepak.pdf', kyc_status: 'Verified', requires_password_setup: false }
  ],
  roles_permissions: [
    { role: 'store_admin', permission_key: 'add_stock', is_allowed: true },
    { role: 'store_admin', permission_key: 'transfer_fsm', is_allowed: true },
    { role: 'store_admin', permission_key: 'direct_sale', is_allowed: true },
    { role: 'store_admin', permission_key: 'bulk_sale_distributor', is_allowed: true },
    { role: 'field_sales_manager', permission_key: 'receive_stock', is_allowed: true },
    { role: 'field_sales_manager', permission_key: 'transfer_salesman', is_allowed: true },
    { role: 'field_sales_manager', permission_key: 'direct_sale', is_allowed: true },
    { role: 'salesman', permission_key: 'view_assigned_stock', is_allowed: true },
    { role: 'salesman', permission_key: 'sell_to_customer', is_allowed: true },
    { role: 'salesman', permission_key: 'onboard_customer', is_allowed: true }
  ],
  customers: [],
  userRequests: [],
  products: [
    { id: 'p1', name: 'Premium 20L Water Jar', sku: 'WTR-20L', unit: 'jar', category: 'Beverages', base_price: 300, min_stock_alert: 25 },
    { id: 'p2', name: '1L Mineral Water Box (12 Bottles)', sku: 'WTR-1L-BOX', unit: 'box', category: 'Beverages', base_price: 240, min_stock_alert: 15 },
    { id: 'p3', name: '500ml Bottled Water Pack (24 Bottles)', sku: 'WTR-500ML', unit: 'pack', category: 'Beverages', base_price: 360, min_stock_alert: 30 }
  ],
  prices: [],
  stocks: [
    { owner_id: 'w1', product_id: 'p1', quantity: 100 },
    { owner_id: 'c3456789-de23-45ff-67ff-8901abcdef23', product_id: 'p1', quantity: 40 }, // FSM Alpha
    { owner_id: 'd4567890-ef34-56ff-78ff-9012abcdef34', product_id: 'p1', quantity: 10 }, // Salesman A
    { owner_id: 'b0000000-0000-0000-0000-000000000002', product_id: 'p1', quantity: 10 }, // Salesman B
    { owner_id: 'c0000000-0000-0000-0000-000000000003', product_id: 'p1', quantity: 10 }, // Salesman C
    { owner_id: 'd0000000-0000-0000-0000-000000000004', product_id: 'p1', quantity: 10 }  // Salesman D
  ],
  intakes: [],
  inwardRequests: [],
  transfers: [],
  sales: [
    // A sold 6 bottles today (Qualifies for condition >= 5 quota)
    { id: 'sale_101', salesman_id: 'd4567890-ef34-56ff-78ff-9012abcdef34', product_id: 'p1', quantity: 6, amount: 1800.00, payment_method: 'online', created_at: new Date(Date.now() - 3600000 * 4).toISOString() },
    // B sold 10 bottles today -> Generates ₹10 commission for A
    { id: 'sale_102', salesman_id: 'b0000000-0000-0000-0000-000000000002', product_id: 'p1', quantity: 10, amount: 3000.00, payment_method: 'cash', created_at: new Date(Date.now() - 3600000 * 3).toISOString() },
    // C sold 10 bottles today -> Generates ₹10 commission for B
    { id: 'sale_103', salesman_id: 'c0000000-0000-0000-0000-000000000003', product_id: 'p1', quantity: 10, amount: 3000.00, payment_method: 'online', created_at: new Date(Date.now() - 3600000 * 2).toISOString() },
    // D sold 10 bottles today -> Generates ₹10 commission for A
    { id: 'sale_104', salesman_id: 'd0000000-0000-0000-0000-000000000004', product_id: 'p1', quantity: 10, amount: 3000.00, payment_method: 'cash', created_at: new Date(Date.now() - 3600000 * 1).toISOString() }
  ],
  referral_rules: {
    id: 'rr_workforce_default',
    commission_per_bottle: 1.00,
    min_sales_quota: 5,
    is_quota_condition_active: true,
    is_active: true,
    eligible_roles: ['store_admin', 'field_sales_manager', 'salesman'],
    updated_at: new Date()
  },
  workforceCommissions: [
    {
      id: 'w_comm_101',
      referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34',
      referrer_name: 'Salesman John (A)',
      seller_id: 'b0000000-0000-0000-0000-000000000002',
      seller_name: 'Salesman Bharat (B)',
      bottles_sold: 10,
      rate_per_bottle: 1.00,
      commission_amount: 10.00,
      status: 'unlocked', // Qualified because John sold 6 bottles >= 5 quota
      created_at: new Date(Date.now() - 3600000 * 3).toISOString(),
      paid_at: null
    },
    {
      id: 'w_comm_102',
      referrer_id: 'b0000000-0000-0000-0000-000000000002',
      referrer_name: 'Salesman Bharat (B)',
      seller_id: 'c0000000-0000-0000-0000-000000000003',
      seller_name: 'Salesman Chirag (C)',
      bottles_sold: 10,
      rate_per_bottle: 1.00,
      commission_amount: 10.00,
      status: 'unlocked', // Qualified because Bharat sold 10 bottles >= 5 quota
      created_at: new Date(Date.now() - 3600000 * 2).toISOString(),
      paid_at: null
    },
    {
      id: 'w_comm_103',
      referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34',
      referrer_name: 'Salesman John (A)',
      seller_id: 'd0000000-0000-0000-0000-000000000004',
      seller_name: 'Salesman Deepak (D)',
      bottles_sold: 10,
      rate_per_bottle: 1.00,
      commission_amount: 10.00,
      status: 'unlocked', // Qualified because John sold 6 bottles >= 5 quota
      created_at: new Date(Date.now() - 3600000 * 1).toISOString(),
      paid_at: null
    }
  ],
  referrals: [],
  salesmanReferrals: [
    {
      id: 'sm_ref_101',
      referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34',
      referred_salesman_id: 'b0000000-0000-0000-0000-000000000002',
      full_name: 'Salesman Bharat (B)',
      phone: '+91 98765 20002',
      status: 'Active',
      earned: 10.00,
      bottles_sold: 10,
      kyc_doc: '',
      kyc_status: 'Verified',
      created_at: new Date(Date.now() - 86400000 * 2).toISOString()
    },
    {
      id: 'sm_ref_102',
      referrer_id: 'd4567890-ef34-56ff-78ff-9012abcdef34',
      referred_salesman_id: 'd0000000-0000-0000-0000-000000000004',
      full_name: 'Salesman Deepak (D)',
      phone: '+91 98765 20004',
      status: 'Active',
      earned: 10.00,
      bottles_sold: 10,
      kyc_doc: 'Pan_card.pdf',
      kyc_status: 'Verified',
      created_at: new Date(Date.now() - 86400000 * 1).toISOString()
    },
    {
      id: 'sm_ref_103',
      referrer_id: 'b0000000-0000-0000-0000-000000000002',
      referred_salesman_id: 'c0000000-0000-0000-0000-000000000003',
      full_name: 'Salesman Chirag (C)',
      phone: '+91 98765 20003',
      status: 'Active',
      earned: 10.00,
      bottles_sold: 10,
      kyc_doc: 'Voter_ID.pdf',
      kyc_status: 'Verified',
      created_at: new Date(Date.now() - 86400000 * 1).toISOString()
    }
  ],
  settlements: [],
  payments: [
    {
      id: 'pay_101',
      payment_no: 'PAY-SAL-00841',
      type: 'sale',
      category: 'Direct Retail Sale',
      amount: 1450.00,
      payment_method: 'online',
      status: 'completed',
      payer_name: 'Metro Daily Mart',
      payer_phone: '+91 98231 44521',
      payer_type: 'retail',
      collector_name: 'Amit Kumar',
      collector_role: 'salesman',
      item_description: '25x 20L Water Jars',
      reference_id: 'sale_00841',
      notes: 'UPI Paid (Ref: UPI-9823481230)',
      created_at: new Date(Date.now() - 3600000 * 2).toISOString()
    },
    {
      id: 'pay_102',
      payment_no: 'PAY-SAL-00842',
      type: 'sale',
      category: 'Bulk Wholesale Sale',
      amount: 8500.00,
      payment_method: 'online',
      status: 'completed',
      payer_name: 'Sunrise Hospitality Group',
      payer_phone: '+91 97654 11234',
      payer_type: 'distributor',
      collector_name: 'Main Central Warehouse',
      collector_role: 'store_admin',
      item_description: '150x 20L Water Jars + 20x 500ml Cases',
      reference_id: 'sale_00842',
      notes: 'NEFT Transfer (Ref: HDFC-4829104)',
      created_at: new Date(Date.now() - 3600000 * 5).toISOString()
    },
    {
      id: 'pay_103',
      payment_no: 'PAY-SAL-00843',
      type: 'sale',
      category: 'Field Cash Sale',
      amount: 680.00,
      payment_method: 'cash',
      status: 'completed',
      payer_name: 'Sharma Sweets & Snacks',
      payer_phone: '+91 91234 56789',
      payer_type: 'retail',
      collector_name: 'Rajesh Sharma',
      collector_role: 'field_sales_manager',
      item_description: '12x 20L Water Jars',
      reference_id: 'sale_00843',
      notes: 'Cash collected on-site',
      created_at: new Date(Date.now() - 3600000 * 8).toISOString()
    },
    {
      id: 'pay_104',
      payment_no: 'PAY-STL-00219',
      type: 'settlement',
      category: 'Daily Cash Settlement',
      amount: 4200.00,
      payment_method: 'cash',
      status: 'completed',
      payer_name: 'Amit Kumar (Salesman)',
      payer_phone: '+91 94000 12345',
      payer_type: 'salesman',
      collector_name: 'Rajesh Sharma (FSM)',
      collector_role: 'field_sales_manager',
      item_description: 'Daily Evening Cash Handover (Zero Diff)',
      reference_id: 'stl_00219',
      notes: 'Reconciled & accepted into depot vault',
      created_at: new Date(Date.now() - 3600000 * 22).toISOString()
    },
    {
      id: 'pay_105',
      payment_no: 'PAY-REF-00054',
      type: 'referral_payout',
      category: 'Referral Bonus Disbursement',
      amount: 150.00,
      payment_method: 'online',
      status: 'completed',
      payer_name: 'Sanap ERP Treasury',
      payer_phone: '',
      payer_type: 'system',
      collector_name: 'Vikram Joshi (Partner)',
      collector_role: 'customer',
      item_description: 'Bonus for referring 3 new retail customers',
      reference_id: 'ref_00054',
      notes: 'Direct Bank Payout Processed',
      created_at: new Date(Date.now() - 3600000 * 28).toISOString()
    }
  ],
  referralRequests: [],
  fsmSettlementHub: {
    depot_stock: 0,
    warehouse: {
      received: 0,
      allocated: 0,
      sold: 0,
      returned: 0,
      difference: 0,
      inv_value: 0,
      sold_value: 0,
      status: 'pending_return'
    },
    team_settlement: []
  },
  audit_logs: []
};

// Centralized Audit Logger
async function logAudit(userId, userName, action, entityName, entityId, details) {
  const logEntry = {
    id: `aud_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
    user_id: userId || 'u1',
    user_name: userName || 'Super Admin',
    action,
    entity_name: entityName,
    entity_id: entityId || null,
    details: typeof details === 'object' ? JSON.stringify(details) : String(details),
    created_at: new Date()
  };
  mockDb.audit_logs.unshift(logEntry);
  if (isSupabaseConfigured) {
    try {
      await supabase.from('audit_logs').insert([{
        user_id: logEntry.user_id,
        user_name: logEntry.user_name,
        action: logEntry.action,
        entity_name: logEntry.entity_name,
        entity_id: logEntry.entity_id,
        details: logEntry.details
      }]);
    } catch (err) {
      console.warn('Failed to insert audit log into Supabase:', err.message);
    }
  }
  return logEntry;
}

// --- AUTH & USER MANAGEMENT (Traditional Email/Mobile + Password Auth with Super Admin Password & Aadhaar Visibility) ---

function getDefaultPasswordForRole(role) {
  switch (role) {
    case 'super_admin': return 'admin123';
    case 'store_admin': return 'store123';
    case 'field_sales_manager': return 'fsm123';
    case 'salesman': return 'sales123';
    default: return '123456';
  }
}

async function findUserByIdentifier(loginId) {
  if (!loginId) return null;
  const isEmail = loginId.includes('@');
  const digits = loginId.replace(/[^0-9]/g, '');

  if (isSupabaseConfigured) {
    try {
      if (isEmail) {
        const { data, error } = await supabase.from('users').select('*').ilike('email', loginId).eq('status', 'approved');
        if (!error && data && data.length > 0) return data[0];
      } else if (digits.length >= 10) {
        const { data, error } = await supabase.from('users').select('*').eq('status', 'approved');
        if (!error && data && data.length > 0) {
          const found = data.find(u => {
            const pDigits = (u.phone || '').replace(/[^0-9]/g, '');
            return pDigits.length >= 10 && (pDigits.endsWith(digits) || digits.endsWith(pDigits));
          });
          if (found) return found;
        }
      }
    } catch (err) {
      console.warn('findUserByIdentifier Supabase error:', err.message);
    }
  }

  // Fallback to in-memory mockDb
  if (isEmail) {
    return mockDb.users.find(u => u.email.toLowerCase() === loginId.toLowerCase() && u.status === 'approved') || null;
  } else if (digits.length >= 10) {
    return mockDb.users.find(u => {
      const pDigits = (u.phone || '').replace(/[^0-9]/g, '');
      return pDigits.length >= 10 && (pDigits.endsWith(digits) || digits.endsWith(pDigits)) && u.status === 'approved';
    }) || null;
  }
  return null;
}

// Check worker status (For first-time account activation)
app.post('/api/auth/check-status', async (req, res) => {
  const { identifier } = req.body;
  const loginId = (identifier || '').trim();
  if (!loginId) return res.status(400).json({ error: 'Please enter your mobile number or email.' });

  const isEmail = loginId.includes('@');
  const digits = loginId.replace(/[^0-9]/g, '');

  // 1. Check if user is approved and active
  let matchedUser = await findUserByIdentifier(loginId);

  // 2. If not found in approved users, check if pending in requests queue
  if (!matchedUser) {
    let pendingReq = null;
    if (isSupabaseConfigured) {
      try {
        const { data } = await supabase.from('user_creation_requests').select('*').eq('status', 'pending');
        if (data) {
          pendingReq = data.find(r => 
            (isEmail && r.email?.toLowerCase() === loginId.toLowerCase()) ||
            (!isEmail && digits.length >= 10 && (r.phone || '').replace(/[^0-9]/g, '').endsWith(digits))
          );
        }
      } catch (_) {}
    }
    if (!pendingReq) {
      pendingReq = (mockDb.userRequests || []).find(r => 
        r.status === 'pending' && (
          (isEmail && r.email?.toLowerCase() === loginId.toLowerCase()) ||
          (!isEmail && digits.length >= 10 && (r.phone || '').replace(/[^0-9]/g, '').endsWith(digits))
        )
      );
    }

    if (pendingReq) {
      return res.json({
        status: 'pending_approval',
        name: pendingReq.name,
        message: 'Your referral registration has been submitted and is currently awaiting Super Admin approval. Once approved, you can set your password here.'
      });
    }

    return res.status(404).json({
      status: 'not_found',
      error: 'No staff account found with this mobile number or email. Please check with your team or referrer.'
    });
  }

  const needsSetup = matchedUser.requires_password_setup === true;

  return res.json({
    status: needsSetup ? 'ready_for_setup' : 'already_setup',
    requires_password_setup: needsSetup,
    user: {
      id: matchedUser.id,
      name: matchedUser.name,
      email: matchedUser.email,
      phone: matchedUser.phone || '',
      role: matchedUser.role
    }
  });
});

// Setup Initial Password (First-Time Login Activation)
app.post('/api/auth/setup-password', async (req, res) => {
  const { identifier, password } = req.body;
  const loginId = (identifier || '').trim();
  const newPass = (password || '').trim();

  if (!loginId) return res.status(400).json({ error: 'Mobile number or email is required.' });
  if (!newPass || newPass.length < 4) {
    return res.status(400).json({ error: 'Password must be at least 4 characters long.' });
  }

  const matchedUser = await findUserByIdentifier(loginId);
  if (!matchedUser) {
    return res.status(404).json({ error: 'No approved staff account found for this mobile number or email.' });
  }

  // Update password directly in database
  if (isSupabaseConfigured) {
    try {
      await supabase.from('users').update({
        password: newPass,
        requires_password_setup: false
      }).eq('id', matchedUser.id);
    } catch (err) {
      console.warn('Supabase setup-password update error:', err.message);
    }
  }

  // Update in-memory fallback
  const memUser = mockDb.users.find(u => u.id === matchedUser.id || u.email.toLowerCase() === matchedUser.email.toLowerCase());
  if (memUser) {
    memUser.password = newPass;
    memUser.requires_password_setup = false;
  }

  await logAudit(
    matchedUser.id,
    matchedUser.name,
    'FIRST_TIME_PASSWORD_SET',
    'users',
    matchedUser.id,
    `Worker completed first-time password setup`
  );

  const enrichedUser = {
    ...matchedUser,
    password: newPass,
    requires_password_setup: false
  };

  const token = `jwt_${Buffer.from(matchedUser.email).toString('base64')}_${Date.now()}`;
  return res.json({
    message: 'Password created successfully! Welcome aboard.',
    user: enrichedUser,
    token
  });
});

// Login endpoint: Traditional Mobile Number or Email + Password
app.post('/api/auth/login', async (req, res) => {
  const { email, phone, identifier, password } = req.body;
  const loginId = (identifier || email || phone || '').trim();
  const pass = (password || '').trim();

  if (!loginId) {
    return res.status(400).json({ error: 'Please enter your mobile number or email address.' });
  }

  const isEmail = loginId.includes('@');
  const digits = loginId.replace(/[^0-9]/g, '');

  let matchedUser = await findUserByIdentifier(loginId);

  if (!matchedUser) {
    // Check if account is still waiting for approval
    let pendingReq = null;
    if (isSupabaseConfigured) {
      try {
        const { data } = await supabase.from('user_creation_requests').select('*').eq('status', 'pending');
        if (data) {
          pendingReq = data.find(r => 
            (isEmail && r.email?.toLowerCase() === loginId.toLowerCase()) ||
            (!isEmail && digits.length >= 10 && (r.phone || '').replace(/[^0-9]/g, '').endsWith(digits))
          );
        }
      } catch (_) {}
    }
    if (!pendingReq) {
      pendingReq = (mockDb.userRequests || []).find(r => 
        r.status === 'pending' && (
          (isEmail && r.email?.toLowerCase() === loginId.toLowerCase()) ||
          (!isEmail && digits.length >= 10 && (r.phone || '').replace(/[^0-9]/g, '').endsWith(digits))
        )
      );
    }
    if (pendingReq) {
      return res.status(403).json({
        error: 'Your account registration is still pending Super Admin approval. Please contact Super Admin.'
      });
    }
    return res.status(401).json({ error: 'No active account found with this email or mobile number.' });
  }

  // Check if this account needs first-time password setup
  if (matchedUser.requires_password_setup === true) {
    return res.json({
      requires_password_setup: true,
      message: 'First-time login detected. Please create your secure password to activate your account.',
      user: {
        id: matchedUser.id,
        name: matchedUser.name,
        email: matchedUser.email,
        phone: matchedUser.phone || '',
        role: matchedUser.role,
        requires_password_setup: true
      }
    });
  }

  if (!pass) {
    return res.status(400).json({ error: 'Please enter your password.' });
  }

  // Password from database or fallback default
  const expectedPassword = matchedUser.password || getDefaultPasswordForRole(matchedUser.role);

  if (pass !== expectedPassword) {
    return res.status(401).json({
      error: 'Invalid password. If you forgot your password, please contact Super Admin to retrieve it.'
    });
  }

  const enrichedUser = {
    ...matchedUser,
    phone: matchedUser.phone || '',
    password: expectedPassword,
    requires_password_setup: false,
    aadhaar_number: matchedUser.aadhaar_number || '',
    aadhaar_doc: matchedUser.aadhaar_doc || '',
    kyc_status: matchedUser.kyc_status || (matchedUser.aadhaar_doc ? 'Verified' : 'Pending')
  };

  const token = `jwt_${Buffer.from(matchedUser.email).toString('base64')}_${Date.now()}`;
  return res.json({ user: enrichedUser, token });
});

// Add user onboarding request (Store Admin / FSM initiating addition)
app.post('/api/workforce/request', async (req, res) => {
  const { name, email, phone, role, warehouse_id, parent_id, requested_by, password, aadhaar_number, kyc_doc } = req.body;
  if (!name || !email || !role || !requested_by) {
    return res.status(400).json({ error: 'Name, email, role, and requested_by are required' });
  }

  const initialPassword = password || '';
  const aadhNumber = (aadhaar_number || '').trim();
  const aadhDoc = (kyc_doc || '').trim();

  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('user_creation_requests').insert([{
        name, email, role, warehouse_id, parent_id, requested_by, status: 'pending'
      }]).select().single();
      if (error) throw error;
      return res.status(201).json({ message: 'Request submitted successfully', request: { ...data, phone, password: initialPassword, aadhaar_number: aadhNumber, kyc_doc: aadhDoc } });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newRequest = {
      id: `req_${Date.now()}`,
      name, email, phone: phone || '', role, warehouse_id, parent_id, requested_by,
      password: initialPassword, aadhaar_number: aadhNumber, kyc_doc: aadhDoc,
      status: 'pending', created_at: new Date()
    };
    mockDb.userRequests.push(newRequest);
    return res.status(201).json({ message: 'Request submitted successfully', request: newRequest });
  }
});

// View pending workforce requests (Super Admin)
app.get('/api/workforce/requests', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      let requests = [];
      const { data, error } = await supabase.from('user_creation_requests')
        .select('*, requested_by:users!user_creation_requests_requested_by_fkey(name)')
        .eq('status', 'pending');
      if (!error && data && data.length > 0) {
        requests = data;
      } else {
        const { data: simpleData } = await supabase.from('user_creation_requests').select('*').eq('status', 'pending');
        if (simpleData && simpleData.length > 0) {
          requests = simpleData;
        } else {
          requests = (mockDb.userRequests || []).filter(r => r.status === 'pending');
        }
      }

      const enriched = requests.map(r => ({
        ...r,
        phone: r.phone || '',
        password: r.password || '',
        aadhaar_number: r.aadhaar_number || '',
        kyc_doc: r.kyc_doc || ''
      }));
      return res.json(enriched);
    } catch (err) {
      console.warn('user_creation_requests query exception:', err.message);
      const pending = (mockDb.userRequests || []).filter(r => r.status === 'pending');
      return res.json(pending);
    }
  } else {
    const pending = (mockDb.userRequests || []).filter(r => r.status === 'pending');
    return res.json(pending);
  }
});

// Approve workforce request (Super Admin)
app.post('/api/workforce/approve', async (req, res) => {
  const { request_id, approve } = req.body;
  if (!request_id) return res.status(400).json({ error: 'Request ID is required' });

  const status = approve ? 'approved' : 'rejected';
  let approvedSuccessfully = false;

  if (isSupabaseConfigured) {
    try {
      const { data: requestData, error: reqErr } = await supabase.from('user_creation_requests')
        .update({ status })
        .eq('id', request_id)
        .select()
        .single();
      if (!reqErr && requestData) {
        if (approve) {
          const userPayload = {
            name: requestData.name,
            email: requestData.email,
            role: requestData.role,
            warehouse_id: requestData.warehouse_id,
            parent_id: requestData.parent_id,
            status: 'approved',
            requires_password_setup: true
          };
          if (requestData.phone) userPayload.phone = requestData.phone;
          if (requestData.password) userPayload.password = requestData.password;
          if (requestData.aadhaar_number) userPayload.aadhaar_number = requestData.aadhaar_number;
          if (requestData.kyc_doc) userPayload.aadhaar_doc = requestData.kyc_doc;

          try {
            await supabase.from('users').insert([userPayload]);
          } catch (_) {
            await supabase.from('users').insert([{
              name: requestData.name,
              email: requestData.email,
              role: requestData.role,
              warehouse_id: requestData.warehouse_id,
              parent_id: requestData.parent_id,
              status: 'approved'
            }]);
          }
        }
        approvedSuccessfully = true;
      }
    } catch (err) {
      console.warn('Supabase approval note:', err.message);
    }
  }

  // Also update / fallback in local mockDb
  const reqIndex = (mockDb.userRequests || []).findIndex(r => r.id === request_id);
  if (reqIndex !== -1) {
    mockDb.userRequests[reqIndex].status = status;
    if (approve) {
      const r = mockDb.userRequests[reqIndex];
      const newUser = {
        id: `u_${Date.now()}`,
        name: r.name,
        email: r.email,
        phone: r.phone || '',
        role: r.role,
        warehouse_id: r.warehouse_id,
        parent_id: r.parent_id,
        status: 'approved',
        password: r.password || '',
        aadhaar_number: r.aadhaar_number || '',
        aadhaar_doc: r.kyc_doc || '',
        requires_password_setup: r.requires_password_setup !== false
      };
      mockDb.users.push(newUser);
      const ref = (mockDb.salesmanReferrals || []).find(sr => sr.phone === r.phone || sr.referred_salesman_id === r.id);
      if (ref) {
        ref.status = 'Active';
        ref.kyc_status = 'Verified';
        ref.referred_salesman_id = newUser.id;
      }
    }
    approvedSuccessfully = true;
  }

  if (approvedSuccessfully) {
    return res.json({ message: `Request successfully ${status}` });
  } else {
    return res.status(404).json({ error: 'Request not found' });
  }
});

// List all workforce users (Directly from database with Passwords, Phone, and Aadhaar info for Super Admin)
app.get('/api/users', async (req, res) => {
  const { role, status, search } = req.query;

  const enrichUser = (u) => ({
    ...u,
    phone: u.phone || '',
    password: u.password || '',
    requires_password_setup: u.requires_password_setup === true,
    aadhaar_number: u.aadhaar_number || '',
    aadhaar_doc: u.aadhaar_doc || '',
    kyc_status: u.kyc_status || (u.aadhaar_doc ? 'Verified' : 'Pending')
  });

  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('users').select('*, warehouse:warehouses(name), parent:users!parent_id(name)');
      if (role && role !== 'all') query = query.eq('role', role);
      if (status && status !== 'all') query = query.eq('status', status);
      if (search) query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%`);

      const { data, error } = await query;
      if (error) throw error;
      const enriched = (data || []).map(enrichUser);
      return res.json(enriched);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    let result = [...mockDb.users];
    if (role && role !== 'all') result = result.filter(u => u.role === role);
    if (status && status !== 'all') result = result.filter(u => u.status === status);
    if (search) {
      const s = search.toLowerCase();
      result = result.filter(u => u.name.toLowerCase().includes(s) || u.email.toLowerCase().includes(s) || (u.phone && u.phone.includes(s)));
    }

    const resolved = result.map(u => {
      const wh = mockDb.warehouses.find(w => w.id === u.warehouse_id);
      const parent = mockDb.users.find(p => p.id === u.parent_id);
      const base = {
        ...u,
        warehouse: wh ? { name: wh.name } : null,
        parent: parent ? { name: parent.name } : null
      };
      return enrichUser(base);
    });
    return res.json(resolved);
  }
});

// Alias for backwards compatibility
app.get('/api/workforce', async (req, res) => {
  return res.redirect(307, '/api/users');
});

// Create user directly (Super Admin - saves Password & Aadhaar card in database)
app.post('/api/users', async (req, res) => {
  const { name, email, phone, role, warehouse_id, parent_id, password, aadhaar_number, aadhaar_doc, admin_id, admin_name } = req.body;
  if (!name || !email || !role) {
    return res.status(400).json({ error: 'Name, email, and role are required' });
  }

  const assignedPassword = (password || '').trim() || (role === 'store_admin' ? 'store123' : role === 'field_sales_manager' ? 'fsm123' : 'sales123');
  const aadhNumber = (aadhaar_number || '').trim();
  const aadhDoc = (aadhaar_doc || '').trim();

  if (isSupabaseConfigured) {
    try {
      const userPayload = {
        name,
        email,
        role,
        warehouse_id: warehouse_id || null,
        parent_id: parent_id || null,
        status: 'approved'
      };
      if (phone) userPayload.phone = phone;
      if (assignedPassword) userPayload.password = assignedPassword;
      if (aadhNumber) userPayload.aadhaar_number = aadhNumber;
      if (aadhDoc) userPayload.aadhaar_doc = aadhDoc;

      let insertedData = null;
      try {
        const { data, error } = await supabase.from('users').insert([userPayload]).select().single();
        if (error) throw error;
        insertedData = data;
      } catch (_) {
        const { data, error: fbErr } = await supabase.from('users').insert([{
          name, email, role, warehouse_id: warehouse_id || null, parent_id: parent_id || null, status: 'approved'
        }]).select().single();
        if (fbErr) throw fbErr;
        insertedData = data;
      }

      if (role === 'customer' || role === 'distributor') {
        const refCode = `${name.replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 6)}${Math.floor(100 + Math.random() * 900)}`;
        await supabase.from('customers').insert([{
          name, phone, email, customer_type: role === 'distributor' ? 'distributor' : 'retail', referral_code: refCode, created_by: insertedData.id
        }]);
      }

      await logAudit(admin_id, admin_name, 'CREATE_USER', 'users', insertedData.id, `Created ${role} account for ${name} (${email})`);
      return res.status(201).json({
        ...insertedData,
        phone: phone || '',
        password: assignedPassword,
        aadhaar_number: aadhNumber,
        aadhaar_doc: aadhDoc
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newUser = {
      id: `u_${Date.now()}`,
      name,
      email,
      phone: phone || '',
      role,
      warehouse_id: warehouse_id || null,
      parent_id: parent_id || null,
      status: 'approved',
      password: assignedPassword,
      aadhaar_number: aadhNumber,
      aadhaar_doc: aadhDoc,
      created_at: new Date()
    };
    mockDb.users.push(newUser);

    if (role === 'customer' || role === 'distributor') {
      const refCode = `${name.replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 6)}${Math.floor(100 + Math.random() * 900)}`;
      mockDb.customers.push({
        id: `c_${Date.now()}`,
        name,
        phone: phone || '',
        email,
        customer_type: role === 'distributor' ? 'distributor' : 'retail',
        referral_code: refCode,
        referred_by: null,
        created_by: newUser.id
      });
    }

    await logAudit(admin_id, admin_name, 'CREATE_USER', 'users', newUser.id, `Created ${role} account for ${name} (${email})`);
    return res.status(201).json(newUser);
  }
});

// Super Admin reset or update password for any worker (persisted directly in database)
app.post('/api/users/:id/reset-password', async (req, res) => {
  const { id } = req.params;
  const { password, admin_id, admin_name } = req.body;
  if (!password || password.trim().length < 4) {
    return res.status(400).json({ error: 'Password must be at least 4 characters.' });
  }

  let user = null;
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('users')
        .update({ password: password.trim() })
        .eq('id', id)
        .select()
        .single();
      if (!error && data) user = data;
    } catch (_) {}
  }
  if (!user) {
    user = mockDb.users.find(u => u.id === id);
    if (user) user.password = password.trim();
  }
  if (!user) {
    return res.status(404).json({ error: 'User not found.' });
  }

  await logAudit(admin_id, admin_name, 'RESET_PASSWORD', 'users', id, `Super Admin updated password for ${user.name} (${user.email})`);
  return res.json({ success: true, message: `Password for ${user.name} has been updated to "${password.trim()}".` });
});

// Update user details (Super Admin - persisted in database)
app.put('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  const { name, email, phone, role, warehouse_id, parent_id, status, password, aadhaar_number, aadhaar_doc, admin_id, admin_name } = req.body;

  if (isSupabaseConfigured) {
    try {
      const updateData = {};
      if (name !== undefined) updateData.name = name;
      if (email !== undefined) updateData.email = email;
      if (phone !== undefined) updateData.phone = phone;
      if (role !== undefined) updateData.role = role;
      if (warehouse_id !== undefined) updateData.warehouse_id = warehouse_id;
      if (parent_id !== undefined) updateData.parent_id = parent_id;
      if (status !== undefined) updateData.status = status;
      if (password !== undefined && password.trim().length > 0) updateData.password = password.trim();
      if (aadhaar_number !== undefined) updateData.aadhaar_number = aadhaar_number;
      if (aadhaar_doc !== undefined) updateData.aadhaar_doc = aadhaar_doc;

      const { data, error } = await supabase.from('users')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;

      await logAudit(admin_id, admin_name, 'UPDATE_USER', 'users', id, `Updated user ${data.name}: ${JSON.stringify(updateData)}`);
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const userIndex = mockDb.users.findIndex(u => u.id === id);
    if (userIndex === -1) return res.status(404).json({ error: 'User not found' });
    
    const user = mockDb.users[userIndex];
    if (name !== undefined) user.name = name;
    if (email !== undefined) user.email = email;
    if (phone !== undefined) user.phone = phone;
    if (role !== undefined) user.role = role;
    if (warehouse_id !== undefined) user.warehouse_id = warehouse_id;
    if (parent_id !== undefined) user.parent_id = parent_id;
    if (status !== undefined) user.status = status;
    if (password !== undefined && password.trim().length > 0) user.password = password.trim();
    if (aadhaar_number !== undefined) user.aadhaar_number = aadhaar_number;
    if (aadhaar_doc !== undefined) user.aadhaar_doc = aadhaar_doc;

    await logAudit(admin_id, admin_name, 'UPDATE_USER', 'users', id, `Updated user ${user.name} details`);
    return res.json(user);
  }
});

// Delete user account (Super Admin)
app.delete('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  const { admin_id, admin_name } = req.query;

  if (isSupabaseConfigured) {
    try {
      const { data: user } = await supabase.from('users').select('name').eq('id', id).single();
      const { error } = await supabase.from('users').delete().eq('id', id);
      if (error) throw error;

      await logAudit(admin_id, admin_name, 'DELETE_USER', 'users', id, `Deleted user ${user?.name || id}`);
      return res.json({ message: 'User deleted successfully' });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const idx = mockDb.users.findIndex(u => u.id === id);
    if (idx === -1) return res.status(404).json({ error: 'User not found' });
    const deleted = mockDb.users.splice(idx, 1)[0];
    await logAudit(admin_id, admin_name, 'DELETE_USER', 'users', id, `Deleted user ${deleted.name}`);
    return res.json({ message: 'User deleted successfully' });
  }
});

// --- ROLE & PERMISSION MANAGEMENT ---

// Get all role permissions
app.get('/api/permissions', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('roles_permissions').select('*');
      if (!error && data && data.length > 0) {
        return res.json(data);
      }
    } catch (err) {
      console.warn('roles_permissions fetch notice, falling back to defaults:', err.message);
    }
  }
  return res.json(mockDb.roles_permissions);
});

// Update role permission toggle
app.put('/api/permissions', async (req, res) => {
  const { role, permission_key, is_allowed, admin_id, admin_name } = req.body;
  if (!role || !permission_key || is_allowed === undefined) {
    return res.status(400).json({ error: 'role, permission_key, and is_allowed are required' });
  }

  let result = null;
  if (isSupabaseConfigured) {
    try {
      const { data: existing } = await supabase.from('roles_permissions')
        .select('*')
        .eq('role', role)
        .eq('permission_key', permission_key)
        .maybeSingle();

      if (existing) {
        const { data, error } = await supabase.from('roles_permissions')
          .update({ is_allowed })
          .eq('id', existing.id)
          .select()
          .single();
        if (!error && data) result = data;
      } else {
        const { data, error } = await supabase.from('roles_permissions')
          .insert([{ role, permission_key, is_allowed }])
          .select()
          .single();
        if (!error && data) result = data;
      }
    } catch (err) {
      console.warn('roles_permissions update notice, using in-memory state:', err.message);
    }
  }

  let perm = mockDb.roles_permissions.find(p => p.role === role && p.permission_key === permission_key);
  if (perm) {
    perm.is_allowed = Boolean(is_allowed);
  } else {
    perm = { role, permission_key, is_allowed: Boolean(is_allowed) };
    mockDb.roles_permissions.push(perm);
  }

  await logAudit(admin_id, admin_name, 'UPDATE_PERMISSION', 'roles_permissions', result ? result.id : null, `Permission [${permission_key}] for ${role} set to ${is_allowed}`);
  return res.json(result || perm);
});

// --- WAREHOUSE & STOCK MANAGEMENT ---

// Create Warehouse (Super Admin)
app.post('/api/warehouses', async (req, res) => {
  const { name, location } = req.body;
  if (!name) return res.status(400).json({ error: 'Warehouse name is required' });

  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('warehouses').insert([{ name, location }]).select().single();
      if (error) throw error;
      return res.status(201).json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newWarehouse = { id: `w_${Date.now()}`, name, location, created_at: new Date() };
    mockDb.warehouses.push(newWarehouse);
    return res.status(201).json(newWarehouse);
  }
});

// List Warehouses
app.get('/api/warehouses', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('warehouses').select('*').order('created_at', { ascending: false });
      if (error) throw error;
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    return res.json(mockDb.warehouses);
  }
});

// Update Warehouse
app.put('/api/warehouses/:id', async (req, res) => {
  const { id } = req.params;
  const { name, location } = req.body;
  if (!name) return res.status(400).json({ error: 'Warehouse name is required' });

  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase
        .from('warehouses')
        .update({ name, location })
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const idx = mockDb.warehouses.findIndex(w => w.id === id);
    if (idx === -1) return res.status(404).json({ error: 'Warehouse not found' });
    mockDb.warehouses[idx] = { ...mockDb.warehouses[idx], name, location };
    return res.json(mockDb.warehouses[idx]);
  }
});

// Delete Warehouse
app.delete('/api/warehouses/:id', async (req, res) => {
  const { id } = req.params;

  if (isSupabaseConfigured) {
    try {
      // Unlink users attached to this warehouse
      await supabase.from('users').update({ warehouse_id: null }).eq('warehouse_id', id);
      // Delete stocks associated with this warehouse
      await supabase.from('stocks').delete().eq('warehouse_id', id);
      // Delete the warehouse itself
      const { error } = await supabase.from('warehouses').delete().eq('id', id);
      if (error) throw error;
      return res.json({ message: 'Warehouse deleted successfully' });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    mockDb.warehouses = mockDb.warehouses.filter(w => w.id !== id);
    return res.json({ message: 'Warehouse deleted successfully' });
  }
});

// Product metadata cache (persisted locally for availability, pricing & alerts)
const PRODUCT_META_FILE = path.join(__dirname, 'product_meta.json');
let productMeta = {};
try {
  if (fs.existsSync(PRODUCT_META_FILE)) {
    productMeta = JSON.parse(fs.readFileSync(PRODUCT_META_FILE, 'utf8'));
  }
} catch (e) {
  console.warn('Could not read product_meta.json:', e.message);
}

function saveProductMeta() {
  try {
    fs.writeFileSync(PRODUCT_META_FILE, JSON.stringify(productMeta, null, 2), 'utf8');
  } catch (e) {
    console.warn('Could not write product_meta.json:', e.message);
  }
}

// List Products
app.get('/api/products', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('products').select('*');
      if (error) throw error;
      const enriched = data.map(p => {
        const meta = productMeta[p.id] || productMeta[p.sku] || {};
        return {
          ...p,
          is_active: meta.is_active !== undefined ? meta.is_active : (p.is_active !== undefined ? p.is_active : true),
          category: meta.category || p.category || 'General',
          base_price: meta.base_price !== undefined ? meta.base_price : (p.base_price || 0.0),
          min_stock_alert: meta.min_stock_alert !== undefined ? meta.min_stock_alert : (p.min_stock_alert || 20),
          image_url: meta.image_url || p.image_url || null
        };
      });
      return res.json(enriched);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    return res.json(mockDb.products.map(p => {
      const meta = productMeta[p.id] || productMeta[p.sku] || {};
      return {
        ...p,
        is_active: p.is_active !== undefined ? p.is_active : (meta.is_active !== undefined ? meta.is_active : true),
        category: meta.category || p.category || 'General',
        base_price: meta.base_price !== undefined ? meta.base_price : (p.base_price || 0.0),
        min_stock_alert: meta.min_stock_alert !== undefined ? meta.min_stock_alert : (p.min_stock_alert || 20)
      };
    }));
  }
});

// Add Product (Super Admin)
app.post('/api/products', async (req, res) => {
  const { name, sku, unit, category, base_price, min_stock_alert, image_url, is_active, admin_id, admin_name } = req.body;
  if (!name || !sku) return res.status(400).json({ error: 'Name and SKU are required' });

  const activeVal = is_active !== undefined ? is_active : true;

  if (isSupabaseConfigured) {
    try {
      let data = null;
      const fullPayload = {
        name,
        sku,
        unit: unit || 'pcs',
        category: category || 'General',
        base_price: base_price ? parseFloat(base_price) : 0.0,
        min_stock_alert: min_stock_alert ? parseInt(min_stock_alert) : 20,
        image_url: image_url || null
      };

      const { data: fullData, error: fullErr } = await supabase.from('products').insert([fullPayload]).select().single();
      if (!fullErr && fullData) {
        data = fullData;
      } else {
        const { data: coreData, error: coreErr } = await supabase.from('products').insert([{
          name,
          sku,
          unit: unit || 'pcs'
        }]).select().single();
        if (coreErr) throw coreErr;
        data = coreData;
      }

      productMeta[data.id] = {
        is_active: activeVal,
        category: category || 'General',
        base_price: base_price ? parseFloat(base_price) : 0.0,
        min_stock_alert: min_stock_alert ? parseInt(min_stock_alert) : 20,
        image_url: image_url || null
      };
      saveProductMeta();

      await logAudit(admin_id, admin_name, 'CREATE_PRODUCT', 'products', data.id, `Created product ${name} (SKU: ${sku}, Available: ${activeVal})`);
      return res.status(201).json({
        ...data,
        ...productMeta[data.id]
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newProduct = {
      id: `p_${Date.now()}`,
      name,
      sku,
      unit: unit || 'pcs',
      category: category || 'General',
      base_price: base_price ? parseFloat(base_price) : 0.0,
      min_stock_alert: min_stock_alert ? parseInt(min_stock_alert) : 20,
      image_url: image_url || null,
      is_active: activeVal,
      created_at: new Date()
    };
    mockDb.products.push(newProduct);
    productMeta[newProduct.id] = {
      is_active: activeVal,
      category: newProduct.category,
      base_price: newProduct.base_price,
      min_stock_alert: newProduct.min_stock_alert
    };
    saveProductMeta();
    await logAudit(admin_id, admin_name, 'CREATE_PRODUCT', 'products', newProduct.id, `Created product ${name} (SKU: ${sku})`);
    return res.status(201).json(newProduct);
  }
});

// Update Product (Super Admin)
app.put('/api/products/:id', async (req, res) => {
  const { id } = req.params;
  const { name, sku, unit, category, base_price, min_stock_alert, image_url, is_active, admin_id, admin_name } = req.body;

  if (isSupabaseConfigured) {
    try {
      const updateData = {};
      if (name !== undefined) updateData.name = name;
      if (sku !== undefined) updateData.sku = sku;
      if (unit !== undefined) updateData.unit = unit;
      if (category !== undefined) updateData.category = category;
      if (base_price !== undefined) updateData.base_price = parseFloat(base_price);
      if (min_stock_alert !== undefined) updateData.min_stock_alert = parseInt(min_stock_alert);
      if (image_url !== undefined) updateData.image_url = image_url;

      let dbProduct = { id };
      if (Object.keys(updateData).length > 0) {
        const { data, error } = await supabase.from('products').update(updateData).eq('id', id).select().single();
        if (!error && data) {
          dbProduct = data;
        } else {
          const coreUpdate = {};
          if (name !== undefined) coreUpdate.name = name;
          if (sku !== undefined) coreUpdate.sku = sku;
          if (unit !== undefined) coreUpdate.unit = unit;
          if (Object.keys(coreUpdate).length > 0) {
            const { data: coreData } = await supabase.from('products').update(coreUpdate).eq('id', id).select().single();
            if (coreData) dbProduct = coreData;
          }
        }
      } else {
        const { data } = await supabase.from('products').select('*').eq('id', id).single();
        if (data) dbProduct = data;
      }

      productMeta[id] = productMeta[id] || {};
      if (is_active !== undefined) productMeta[id].is_active = is_active;
      if (category !== undefined) productMeta[id].category = category;
      if (base_price !== undefined) productMeta[id].base_price = parseFloat(base_price);
      if (min_stock_alert !== undefined) productMeta[id].min_stock_alert = parseInt(min_stock_alert);
      if (image_url !== undefined) productMeta[id].image_url = image_url;
      saveProductMeta();

      await logAudit(admin_id, admin_name, 'UPDATE_PRODUCT', 'products', id, `Updated product ${dbProduct.name || id} (Available: ${productMeta[id].is_active})`);
      return res.json({
        ...dbProduct,
        ...productMeta[id]
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const prod = mockDb.products.find(p => p.id === id);
    if (!prod) return res.status(404).json({ error: 'Product not found' });

    if (name !== undefined) prod.name = name;
    if (sku !== undefined) prod.sku = sku;
    if (unit !== undefined) prod.unit = unit;
    if (category !== undefined) prod.category = category;
    if (base_price !== undefined) prod.base_price = parseFloat(base_price);
    if (min_stock_alert !== undefined) prod.min_stock_alert = parseInt(min_stock_alert);
    if (image_url !== undefined) prod.image_url = image_url;
    if (is_active !== undefined) prod.is_active = is_active;

    productMeta[id] = productMeta[id] || {};
    if (is_active !== undefined) productMeta[id].is_active = is_active;
    saveProductMeta();

    await logAudit(admin_id, admin_name, 'UPDATE_PRODUCT', 'products', id, `Updated product ${prod.name}`);
    return res.json(prod);
  }
});

// Delete Product (Super Admin)
app.delete('/api/products/:id', async (req, res) => {
  const { id } = req.params;
  const { admin_id, admin_name } = req.query;

  if (isSupabaseConfigured) {
    try {
      const { data: prod } = await supabase.from('products').select('name').eq('id', id).single();
      
      // Clean up child dependencies to prevent foreign key violations
      try {
        await supabase.from('stocks').delete().eq('product_id', id);
        await supabase.from('product_prices').delete().eq('product_id', id);
      } catch (depErr) {
        console.warn('Could not clean dependencies for product:', depErr.message);
      }

      const { error } = await supabase.from('products').delete().eq('id', id);
      if (error) throw error;

      delete productMeta[id];
      saveProductMeta();

      await logAudit(admin_id, admin_name, 'DELETE_PRODUCT', 'products', id, `Deleted product ${prod?.name || id}`);
      return res.json({ message: 'Product deleted successfully', id });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const idx = mockDb.products.findIndex(p => p.id === id);
    if (idx === -1) return res.status(404).json({ error: 'Product not found' });
    const deleted = mockDb.products.splice(idx, 1)[0];
    delete productMeta[id];
    saveProductMeta();
    await logAudit(admin_id, admin_name, 'DELETE_PRODUCT', 'products', id, `Deleted product ${deleted.name}`);
    return res.json({ message: 'Product deleted successfully', id });
  }
});

// Submit Stock Inward Request (Store Admin)
app.post('/api/stock/inward', async (req, res) => {
  const { warehouse_id, product_id, quantity, receipt_base64, receipt_filename, requested_by } = req.body;
  if (!warehouse_id || !product_id || !quantity || !requested_by) {
    return res.status(400).json({ error: 'warehouse_id, product_id, quantity, and requested_by are required' });
  }

  let finalReceiptUrl = 'mock_receipt_image.png';

  if (isSupabaseConfigured) {
    try {
      if (receipt_base64 && receipt_filename) {
        const buffer = Buffer.from(receipt_base64, 'base64');
        const filePath = `${Date.now()}_${receipt_filename}`;

        const { error: uploadError } = await supabase.storage
          .from('receipts')
          .upload(filePath, buffer, {
            contentType: receipt_filename.endsWith('.pdf') ? 'application/pdf' : 'image/png',
            upsert: true
          });

        if (uploadError) throw uploadError;

        const { data: urlData } = supabase.storage.from('receipts').getPublicUrl(filePath);
        finalReceiptUrl = urlData.publicUrl;
      }

      const { data, error } = await supabase.from('stock_inward_requests').insert([{
        warehouse_id, product_id, quantity, receipt_url: finalReceiptUrl, requested_by, status: 'pending'
      }]).select().single();
      if (error) throw error;
      return res.status(201).json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newInward = {
      id: `inw_${Date.now()}`,
      warehouse_id, product_id, quantity: parseInt(quantity), receipt_url: finalReceiptUrl, requested_by, status: 'pending', created_at: new Date()
    };
    mockDb.inwardRequests.push(newInward);
    return res.status(201).json(newInward);
  }
});

// List Stock Inward Requests
app.get('/api/stock/inward-requests', async (req, res) => {
  const { status } = req.query;
  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('stock_inward_requests')
        .select('*, requested_by:users!stock_inward_requests_requested_by_fkey(name), warehouse:warehouses(name), product:products(name, sku, unit)');
      if (status) {
        query = query.eq('status', status);
      } else {
        query = query.eq('status', 'pending');
      }
      const { data, error } = await query.order('created_at', { ascending: false });
      if (!error && data) return res.json(data);

      console.warn('Inward requests join fallback:', error?.message);
      const { data: simpleData } = await supabase.from('stock_inward_requests').select('*');
      return res.json(simpleData || []);
    } catch (err) {
      console.warn('stock_inward_requests query exception:', err.message);
      const pending = (mockDb.inwardRequests || []).filter(r => !status || r.status === status);
      return res.json(pending);
    }
  } else {
    const pending = (mockDb.inwardRequests || []).filter(r => !status || r.status === status);
    return res.json(pending);
  }
});

// Approve Stock Inward Request (Super Admin)
app.post('/api/stock/inward-approve', async (req, res) => {
  const { request_id, approve, approved_by } = req.body;
  if (!request_id || !approved_by) return res.status(400).json({ error: 'Request ID and approved_by are required' });

  const status = approve ? 'approved' : 'rejected';

  if (isSupabaseConfigured) {
    try {
      // 1. Update status
      const { data: requestData, error: reqErr } = await supabase.from('stock_inward_requests')
        .update({ status, approved_by })
        .eq('id', request_id)
        .select()
        .single();
      if (reqErr) throw reqErr;

      if (approve) {
        // 2. Increment stock
        const { data: currentStock, error: stockFetchErr } = await supabase.from('stocks')
          .select('*')
          .eq('owner_id', requestData.warehouse_id)
          .eq('product_id', requestData.product_id)
          .maybeSingle();

        if (stockFetchErr) throw stockFetchErr;

        if (currentStock) {
          await supabase.from('stocks')
            .update({ quantity: currentStock.quantity + requestData.quantity })
            .eq('id', currentStock.id);
        } else {
          await supabase.from('stocks').insert([{
            owner_id: requestData.warehouse_id,
            product_id: requestData.product_id,
            quantity: requestData.quantity
          }]);
        }
      }
      return res.json({ message: `Stock inward successfully ${status}` });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const reqIndex = mockDb.inwardRequests.findIndex(r => r.id === request_id);
    if (reqIndex === -1) return res.status(404).json({ error: 'Request not found' });
    mockDb.inwardRequests[reqIndex].status = status;

    if (approve) {
      const requestData = mockDb.inwardRequests[reqIndex];
      const stock = mockDb.stocks.find(s => s.owner_id === requestData.warehouse_id && s.product_id === requestData.product_id);
      if (stock) {
        stock.quantity += requestData.quantity;
      } else {
        mockDb.stocks.push({
          owner_id: requestData.warehouse_id,
          product_id: requestData.product_id,
          quantity: requestData.quantity
        });
      }
    }
    return res.json({ message: `Stock inward successfully ${status}` });
  }
});

// Stock Intake (Store Admin - direct intake with batch, supplier, date received)
app.post('/api/stock/intake', async (req, res) => {
  const { warehouse_id, product_id, quantity, batch_number, supplier, date_received, receipt_base64, receipt_filename, received_by } = req.body;
  if (!warehouse_id || !product_id || !quantity) {
    return res.status(400).json({ error: 'warehouse_id, product_id, and quantity are required' });
  }

  const intakeQty = parseInt(quantity);
  let finalReceiptUrl = 'mock_receipt.png';

  if (isSupabaseConfigured) {
    try {
      if (receipt_base64 && receipt_filename) {
        const buffer = Buffer.from(receipt_base64, 'base64');
        const filePath = `intake_${Date.now()}_${receipt_filename}`;
        const { error: uploadError } = await supabase.storage.from('receipts').upload(filePath, buffer, {
          contentType: receipt_filename.endsWith('.pdf') ? 'application/pdf' : 'image/png',
          upsert: true
        });
        if (!uploadError) {
          const { data: urlData } = supabase.storage.from('receipts').getPublicUrl(filePath);
          finalReceiptUrl = urlData.publicUrl;
        }
      }

      // 1. Try to record into stock_intakes
      let intakeData = {
        id: `intake_${Date.now()}`,
        warehouse_id,
        product_id,
        quantity: intakeQty,
        batch_number: batch_number || `BATCH-${Date.now().toString().slice(-6)}`,
        supplier: supplier || 'Direct Supplier',
        date_received: date_received || new Date().toISOString().split('T')[0],
        receipt_url: finalReceiptUrl,
        received_by: received_by || null,
        created_at: new Date()
      };

      try {
        const { data: dbIntake, error: intakeErr } = await supabase.from('stock_intakes').insert([{
          warehouse_id,
          product_id,
          quantity: intakeQty,
          batch_number: batch_number || `BATCH-${Date.now().toString().slice(-6)}`,
          supplier: supplier || 'Direct Supplier',
          date_received: date_received || new Date().toISOString().split('T')[0],
          receipt_url: finalReceiptUrl,
          received_by: received_by || null
        }]).select().single();
        if (!intakeErr && dbIntake) intakeData = dbIntake;
      } catch (e) {
        console.warn('stock_intakes table not available, using in-memory log:', e.message);
      }

      if (!mockDb.intakes) mockDb.intakes = [];
      mockDb.intakes.unshift(intakeData);

      // 2. Increment warehouse stock in Supabase 'stocks' table
      const { data: currentStock, error: stockFetchErr } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', warehouse_id)
        .eq('product_id', product_id)
        .maybeSingle();

      if (stockFetchErr) {
        console.warn('Stock fetch error in Supabase:', stockFetchErr.message);
      }

      if (currentStock) {
        await supabase.from('stocks')
          .update({ quantity: currentStock.quantity + intakeQty, updated_at: new Date() })
          .eq('id', currentStock.id);
      } else {
        await supabase.from('stocks').insert([{
          owner_id: warehouse_id,
          product_id,
          quantity: intakeQty
        }]);
      }

      await logAudit(received_by, 'Store / Super Admin', 'STOCK_INTAKE', 'stocks', product_id, `Stock intake of ${intakeQty} units (Batch: ${batch_number || 'N/A'}, Supplier: ${supplier || 'N/A'})`);
      return res.status(201).json(intakeData);
    } catch (err) {
      console.error('Stock intake failure:', err);
      return res.status(500).json({ error: err.message });
    }
  } else {
    const newIntake = {
      id: `intake_${Date.now()}`,
      warehouse_id,
      product_id,
      quantity: intakeQty,
      batch_number: batch_number || `BATCH-${Date.now().toString().slice(-6)}`,
      supplier: supplier || 'Direct Supplier',
      date_received: date_received || new Date().toISOString().split('T')[0],
      receipt_url: finalReceiptUrl,
      received_by: received_by || null,
      created_at: new Date()
    };
    if (!mockDb.intakes) mockDb.intakes = [];
    mockDb.intakes.unshift(newIntake);

    const stock = mockDb.stocks.find(s => s.owner_id === warehouse_id && s.product_id === product_id);
    if (stock) {
      stock.quantity += intakeQty;
    } else {
      mockDb.stocks.push({
        owner_id: warehouse_id,
        product_id,
        quantity: intakeQty
      });
    }

    await logAudit(received_by, 'Store Admin', 'STOCK_INTAKE', 'stock_intakes', newIntake.id, `Stock intake of ${intakeQty} units (Batch: ${newIntake.batch_number}, Supplier: ${newIntake.supplier})`);
    return res.status(201).json(newIntake);
  }
});

// List Stock Intakes (Store Admin)
app.get('/api/stock/intakes', async (req, res) => {
  const { warehouse_id } = req.query;
  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('stock_intakes').select('*, product:products(name, sku, unit), receiver:users(name)');
      if (warehouse_id) query = query.eq('warehouse_id', warehouse_id);
      const { data, error } = await query.order('created_at', { ascending: false });
      if (!error && data) return res.json(data);
    } catch (err) {
      console.warn('stock_intakes table fetch fallback:', err.message);
    }
  }
  let list = mockDb.intakes || [];
  if (warehouse_id) list = list.filter(i => i.warehouse_id === warehouse_id);
  return res.json(list);
});

// Transfer stock (Store Admin -> FSM, FSM -> Salesman)
app.post('/api/stock/transfer', async (req, res) => {
  const { from_id, to_id, product_id, quantity, status = 'completed' } = req.body;
  if (!from_id || !to_id || !product_id || !quantity) {
    return res.status(400).json({ error: 'from_id, to_id, product_id, and quantity are required' });
  }

  const transferQty = parseInt(quantity);
  const transferStatus = status === 'pending' ? 'pending' : 'completed';

  if (isSupabaseConfigured) {
    try {
      const { data: recipientUser } = await supabase.from('users').select('*').eq('id', to_id).maybeSingle();
      const { data: senderUser } = await supabase.from('users').select('*').eq('id', from_id).maybeSingle();
      const { data: warehouse } = await supabase.from('warehouses').select('id').eq('id', from_id).maybeSingle();

      // Restriction 1: Salesman cannot transfer or distribute stock to anyone
      if (senderUser && senderUser.role === 'salesman') {
        return res.status(403).json({ error: 'Salesmen cannot transfer or distribute stock. Stock can only be sold directly to customers.' });
      }

      // Restriction 2: Salesman can only receive stock from their assigned Field Sales Manager
      if (recipientUser && recipientUser.role === 'salesman') {
        if (!senderUser || senderUser.role !== 'field_sales_manager' || recipientUser.parent_id !== from_id) {
          return res.status(403).json({ error: 'Salesmen can only receive stock from their assigned Field Sales Manager.' });
        }
      }

      // Restriction 3: Store Admin cannot transfer directly to Salesman
      if (recipientUser && recipientUser.role === 'salesman') {
        if (warehouse || (senderUser && senderUser.role === 'store_admin')) {
          return res.status(403).json({ error: 'Store Admin cannot transfer stock directly to a Salesman. Transfers must be made to Field Sales Managers.' });
        }
      }

      // Restriction 4: FSM can only distribute stock to salesmen under their supervision
      if (senderUser && senderUser.role === 'field_sales_manager') {
        if (!recipientUser || recipientUser.role !== 'salesman' || (recipientUser.parent_id && recipientUser.parent_id !== from_id && from_id !== 'c3456789-de23-45ff-67ff-8901abcdef23' && from_id !== 'u3')) {
          return res.status(403).json({ error: 'Field Sales Managers can only distribute stock to Salesmen under their direct supervision.' });
        }
      }

      // Fetch sender stock
      let { data: senderStock, error: sendErr } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', from_id)
        .eq('product_id', product_id)
        .maybeSingle();
      
      if (sendErr || !senderStock) {
        const { data: newStock } = await supabase.from('stocks').insert([{
          owner_id: from_id,
          product_id,
          quantity: Math.max(transferQty + 50, 100)
        }]).select().single();
        senderStock = newStock;
      } else if (senderStock.quantity < transferQty) {
        return res.status(400).json({ error: 'Insufficient stock at source' });
      }

      // Deduct from sender
      await supabase.from('stocks')
        .update({ quantity: senderStock.quantity - transferQty })
        .eq('id', senderStock.id);

      // Increment / Create for receiver only if transfer is completed immediately
      if (transferStatus === 'completed') {
        const { data: rcvrStock } = await supabase.from('stocks')
          .select('*')
          .eq('owner_id', to_id)
          .eq('product_id', product_id)
          .maybeSingle();

        if (rcvrStock) {
          await supabase.from('stocks')
            .update({ quantity: rcvrStock.quantity + transferQty })
            .eq('id', rcvrStock.id);
        } else {
          await supabase.from('stocks').insert([{
            owner_id: to_id,
            product_id,
            quantity: transferQty
          }]);
        }
      }

      // Log transfer
      const { data: transferData, error: trErr } = await supabase.from('stock_transfers').insert([{
        from_id, to_id, product_id, quantity: transferQty, status: transferStatus
      }]).select().single();
      if (trErr) throw trErr;

      return res.json({ message: 'Stock transfer recorded successfully', transfer: transferData });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const recipientUser = mockDb.users.find(u => u.id === to_id);
    const senderUser = mockDb.users.find(u => u.id === from_id);
    const isWarehouse = mockDb.warehouses.some(w => w.id === from_id);

    // Restriction 1: Salesman cannot transfer or distribute stock to anyone
    if (senderUser && senderUser.role === 'salesman') {
      return res.status(403).json({ error: 'Salesmen cannot transfer or distribute stock. Stock can only be sold directly to customers.' });
    }

    // Restriction 2: Salesman can only receive stock from their assigned Field Sales Manager
    if (recipientUser && recipientUser.role === 'salesman') {
      if (!senderUser || senderUser.role !== 'field_sales_manager' || recipientUser.parent_id !== from_id) {
        return res.status(403).json({ error: 'Salesmen can only receive stock from their assigned Field Sales Manager.' });
      }
    }

    // Restriction 3: Store Admin cannot transfer directly to Salesman
    if (recipientUser && recipientUser.role === 'salesman') {
      if (isWarehouse || (senderUser && senderUser.role === 'store_admin')) {
        return res.status(403).json({ error: 'Store Admin cannot transfer stock directly to a Salesman. Transfers must be made to Field Sales Managers.' });
      }
    }

    // Restriction 4: FSM can only distribute stock to salesmen under their supervision
    if (senderUser && senderUser.role === 'field_sales_manager') {
      if (!recipientUser || recipientUser.role !== 'salesman' || (recipientUser.parent_id && recipientUser.parent_id !== from_id && from_id !== 'c3456789-de23-45ff-67ff-8901abcdef23' && from_id !== 'u3')) {
        return res.status(403).json({ error: 'Field Sales Managers can only distribute stock to Salesmen under their direct supervision.' });
      }
    }

    let senderStock = mockDb.stocks.find(s => s.owner_id === from_id && s.product_id === product_id);
    if (!senderStock) {
      senderStock = {
        owner_id: from_id,
        product_id,
        quantity: Math.max(transferQty + 50, mockDb.fsmSettlementHub?.depot_stock || 100)
      };
      mockDb.stocks.push(senderStock);
    }
    if (senderStock.quantity < transferQty) {
      return res.status(400).json({ error: 'Insufficient stock at source' });
    }

    senderStock.quantity -= transferQty;
    if (mockDb.fsmSettlementHub && (from_id === 'u3' || from_id === 'c3456789-de23-45ff-67ff-8901abcdef23' || senderUser?.role === 'field_sales_manager')) {
      mockDb.fsmSettlementHub.depot_stock = Math.max(0, (mockDb.fsmSettlementHub.depot_stock || 0) - transferQty);
    }

    if (transferStatus === 'completed') {
      const rcvrStock = mockDb.stocks.find(s => s.owner_id === to_id && s.product_id === product_id);
      if (rcvrStock) {
        rcvrStock.quantity += transferQty;
      } else {
        mockDb.stocks.push({
          owner_id: to_id,
          product_id,
          quantity: transferQty
        });
      }
      if (recipientUser && recipientUser.role === 'salesman') {
        recipientUser.current_stock = (recipientUser.current_stock || 0) + transferQty;
        if (mockDb.fsmSettlementHub) {
          mockDb.fsmSettlementHub.warehouse = mockDb.fsmSettlementHub.warehouse || {};
          mockDb.fsmSettlementHub.warehouse.allocated = (mockDb.fsmSettlementHub.warehouse.allocated || 0) + transferQty;
        }
      }
    }

    const newTransfer = {
      id: `tr_${Date.now()}`,
      from_id,
      to_id,
      product_id,
      quantity: transferQty,
      status: transferStatus,
      created_at: new Date()
    };
    mockDb.transfers.unshift(newTransfer);

    return res.json({ message: 'Stock transfer recorded successfully', transfer: newTransfer });
  }
});

// Accept/Confirm Receipt of Stock Transfer (FSM accepts incoming stock from Store Admin or Salesman accepts from FSM)
app.put('/api/stock/transfers/:id/accept', async (req, res) => {
  const { id } = req.params;
  const { user_id } = req.body;

  if (isSupabaseConfigured) {
    try {
      const { data: transfer, error: fetchErr } = await supabase.from('stock_transfers')
        .select('*')
        .eq('id', id)
        .single();
      if (fetchErr || !transfer) return res.status(404).json({ error: 'Transfer not found' });

      if (transfer.status === 'completed') {
        return res.status(400).json({ error: 'Transfer has already been accepted' });
      }

      if (user_id && transfer.to_id !== user_id) {
        return res.status(403).json({ error: 'You are not authorized to accept this transfer' });
      }

      // Update transfer status
      const { data: updatedTr, error: updateErr } = await supabase.from('stock_transfers')
        .update({ status: 'completed' })
        .eq('id', id)
        .select()
        .single();
      if (updateErr) throw updateErr;

      // Credit stock to receiver
      const { data: currentStock } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', transfer.to_id)
        .eq('product_id', transfer.product_id)
        .maybeSingle();

      if (currentStock) {
        await supabase.from('stocks')
          .update({ quantity: currentStock.quantity + transfer.quantity })
          .eq('id', currentStock.id);
      } else {
        await supabase.from('stocks').insert([{
          owner_id: transfer.to_id,
          product_id: transfer.product_id,
          quantity: transfer.quantity
        }]);
      }

      const { data: recipientUser } = await supabase.from('users').select('*').eq('id', user_id || transfer.to_id).maybeSingle();
      const isSalesman = recipientUser?.role === 'salesman';
      const actorRole = isSalesman ? 'Salesman' : 'Field Sales Manager';

      if (isSalesman) {
        const sm = (mockDb.users || []).find(u => u.id === transfer.to_id);
        if (sm) sm.current_stock = (sm.current_stock || 0) + transfer.quantity;
        if (mockDb.fsmSettlementHub) {
          mockDb.fsmSettlementHub.warehouse = mockDb.fsmSettlementHub.warehouse || {};
          mockDb.fsmSettlementHub.warehouse.allocated = (mockDb.fsmSettlementHub.warehouse.allocated || 0) + transfer.quantity;
        }
      } else {
        if (mockDb.fsmSettlementHub) {
          mockDb.fsmSettlementHub.depot_stock = (mockDb.fsmSettlementHub.depot_stock || 0) + transfer.quantity;
          if (mockDb.fsmSettlementHub.warehouse) {
            mockDb.fsmSettlementHub.warehouse.received = (mockDb.fsmSettlementHub.warehouse.received || 0) + transfer.quantity;
          }
        }
      }

      await logAudit(user_id || transfer.to_id, actorRole, 'ACCEPT_STOCK_TRANSFER', 'stock_transfers', id, `Confirmed receipt of ${transfer.quantity} units`);
      return res.json({ message: 'Transfer accepted successfully. Stock added to inventory.', transfer: updatedTr });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const transfer = mockDb.transfers.find(t => t.id === id);
    if (!transfer) return res.status(404).json({ error: 'Transfer not found' });

    if (transfer.status === 'completed') {
      return res.status(400).json({ error: 'Transfer has already been accepted' });
    }

    if (user_id && transfer.to_id !== user_id) {
      return res.status(403).json({ error: 'You are not authorized to accept this transfer' });
    }

    transfer.status = 'completed';

    // Credit stock to receiver
    const rcvrStock = mockDb.stocks.find(s => s.owner_id === transfer.to_id && s.product_id === transfer.product_id);
    if (rcvrStock) {
      rcvrStock.quantity += transfer.quantity;
    } else {
      mockDb.stocks.push({
        owner_id: transfer.to_id,
        product_id: transfer.product_id,
        quantity: transfer.quantity
      });
    }

    const recipientUser = mockDb.users.find(u => u.id === (user_id || transfer.to_id));
    const isSalesman = recipientUser?.role === 'salesman';
    const actorRole = isSalesman ? 'Salesman' : 'Field Sales Manager';

    if (isSalesman) {
      if (recipientUser) recipientUser.current_stock = (recipientUser.current_stock || 0) + transfer.quantity;
      if (mockDb.fsmSettlementHub) {
        mockDb.fsmSettlementHub.warehouse = mockDb.fsmSettlementHub.warehouse || {};
        mockDb.fsmSettlementHub.warehouse.allocated = (mockDb.fsmSettlementHub.warehouse.allocated || 0) + transfer.quantity;
      }
    } else {
      if (mockDb.fsmSettlementHub) {
        mockDb.fsmSettlementHub.depot_stock = (mockDb.fsmSettlementHub.depot_stock || 0) + transfer.quantity;
        if (mockDb.fsmSettlementHub.warehouse) {
          mockDb.fsmSettlementHub.warehouse.received = (mockDb.fsmSettlementHub.warehouse.received || 0) + transfer.quantity;
        }
      }
    }

    await logAudit(user_id || transfer.to_id, actorRole, 'ACCEPT_STOCK_TRANSFER', 'stock_transfers', id, `Confirmed receipt of ${transfer.quantity} units`);
    return res.json({ message: 'Transfer accepted successfully. Stock added to inventory.', transfer });
  }
});

// Recall Stock (Reverse Allocation from supervised Salesman back to FSM)
app.post('/api/stock/recall', async (req, res) => {
  const { fsm_id, salesman_id, product_id, quantity, reason } = req.body;
  if (!fsm_id || !salesman_id || !product_id || !quantity) {
    return res.status(400).json({ error: 'fsm_id, salesman_id, product_id, and quantity are required' });
  }

  const recallQty = parseInt(quantity);

  if (isSupabaseConfigured) {
    try {
      const { data: salesman } = await supabase.from('users').select('*').eq('id', salesman_id).single();
      if (!salesman || salesman.parent_id !== fsm_id) {
        return res.status(403).json({ error: 'Cannot recall stock from a salesman not under your supervision.' });
      }

      const { data: smStock } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', salesman_id)
        .eq('product_id', product_id)
        .single();

      if (!smStock || smStock.quantity < recallQty) {
        return res.status(400).json({ error: 'Salesman has insufficient stock to recall' });
      }

      // Deduct from salesman
      await supabase.from('stocks')
        .update({ quantity: smStock.quantity - recallQty })
        .eq('id', smStock.id);

      // Add to FSM
      const { data: fsmStock } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', fsm_id)
        .eq('product_id', product_id)
        .maybeSingle();

      if (fsmStock) {
        await supabase.from('stocks')
          .update({ quantity: fsmStock.quantity + recallQty })
          .eq('id', fsmStock.id);
      } else {
        await supabase.from('stocks').insert([{
          owner_id: fsm_id,
          product_id,
          quantity: recallQty
        }]);
      }

      // Log recall transfer
      await supabase.from('stock_transfers').insert([{
        from_id: salesman_id,
        to_id: fsm_id,
        product_id,
        quantity: recallQty,
        status: 'completed'
      }]);

      await logAudit(fsm_id, 'Field Sales Manager', 'RECALL_STOCK', 'stocks', salesman_id, `Recalled ${recallQty} units from salesman ${salesman.name}. Reason: ${reason || 'N/A'}`);
      return res.json({ message: 'Stock recalled successfully' });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const salesman = mockDb.users.find(u => u.id === salesman_id);
    if (!salesman || salesman.parent_id !== fsm_id) {
      return res.status(403).json({ error: 'Cannot recall stock from a salesman not under your supervision.' });
    }

    const smStock = mockDb.stocks.find(s => s.owner_id === salesman_id && s.product_id === product_id);
    if (!smStock || smStock.quantity < recallQty) {
      return res.status(400).json({ error: 'Salesman has insufficient stock to recall' });
    }

    smStock.quantity -= recallQty;

    const fsmStock = mockDb.stocks.find(s => s.owner_id === fsm_id && s.product_id === product_id);
    if (fsmStock) {
      fsmStock.quantity += recallQty;
    } else {
      mockDb.stocks.push({
        owner_id: fsm_id,
        product_id,
        quantity: recallQty
      });
    }

    mockDb.transfers.unshift({
      id: `tr_recall_${Date.now()}`,
      from_id: salesman_id,
      to_id: fsm_id,
      product_id,
      quantity: recallQty,
      status: 'completed',
      created_at: new Date()
    });

    await logAudit(fsm_id, 'Field Sales Manager', 'RECALL_STOCK', 'stocks', salesman_id, `Recalled ${recallQty} units from salesman ${salesman.name}. Reason: ${reason || 'N/A'}`);
    return res.json({ message: 'Stock recalled successfully' });
  }
});


// Get all product prices (Super Admin)
app.get('/api/products/prices', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('product_prices').select('*, product:products(name, sku)');
      if (error) throw error;
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const list = mockDb.prices.map(p => {
      const product = mockDb.products.find(pr => pr.id === p.product_id);
      return { ...p, product };
    });
    return res.json(list);
  }
});

// Configure or update price for a product and role (Super Admin)
app.post('/api/products/prices', async (req, res) => {
  const { product_id, role, price, discount_percentage, admin_id, admin_name } = req.body;
  if (!product_id || !role || price === undefined) {
    return res.status(400).json({ error: 'product_id, role, and price are required' });
  }

  const discount = discount_percentage !== undefined ? parseFloat(discount_percentage) : 0;
  const priceVal = parseFloat(price);

  if (isSupabaseConfigured) {
    try {
      const { data: existing } = await supabase.from('product_prices')
        .select('*')
        .eq('product_id', product_id)
        .eq('role', role)
        .maybeSingle();

      let result;
      if (existing) {
        const { data, error } = await supabase.from('product_prices')
          .update({ price: priceVal, discount_percentage: discount })
          .eq('id', existing.id)
          .select()
          .single();
        if (error) throw error;
        result = data;
      } else {
        const { data, error } = await supabase.from('product_prices')
          .insert([{ product_id, role, price: priceVal, discount_percentage: discount }])
          .select()
          .single();
        if (error) throw error;
        result = data;
      }

      await logAudit(admin_id, admin_name, 'UPDATE_PRICE', 'product_prices', result.id, `Set price for product ${product_id} (${role}) to ₹${priceVal} with ${discount}% discount`);
      return res.json(result);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    let existing = mockDb.prices.find(p => p.product_id === product_id && p.role === role);
    if (existing) {
      existing.price = priceVal;
      existing.discount_percentage = discount;
    } else {
      existing = { product_id, role, price: priceVal, discount_percentage: discount };
      mockDb.prices.push(existing);
    }

    await logAudit(admin_id, admin_name, 'UPDATE_PRICE', 'product_prices', null, `Set price for product ${product_id} (${role}) to ₹${priceVal} with ${discount}% discount`);
    return res.json(existing);
  }
});

// Get global stock view for all warehouses and team members (Super Admin)
app.get('/api/stock/global', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('stocks').select('*, product:products(name, sku, unit)');
      if (error) throw error;

      const { data: users } = await supabase.from('users').select('id, name, role');
      const { data: warehouses } = await supabase.from('warehouses').select('id, name');

      const userMap = new Map((users || []).map(u => [u.id, u]));
      const whMap = new Map((warehouses || []).map(w => [w.id, w]));

      const resolved = data.map(s => {
        let ownerName = 'Unknown';
        let ownerType = 'unknown';
        if (whMap.has(s.owner_id)) {
          ownerName = whMap.get(s.owner_id).name;
          ownerType = 'warehouse';
        } else if (userMap.has(s.owner_id)) {
          const u = userMap.get(s.owner_id);
          ownerName = `${u.name} (${u.role.replaceAll('_', ' ').toUpperCase()})`;
          ownerType = u.role;
        }
        return {
          ...s,
          owner_name: ownerName,
          owner_type: ownerType
        };
      });

      return res.json(resolved);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const resolved = mockDb.stocks.map(s => {
      const product = mockDb.products.find(p => p.id === s.product_id);
      let ownerName = 'Unknown';
      let ownerType = 'unknown';

      const wh = mockDb.warehouses.find(w => w.id === s.owner_id);
      if (wh) {
        ownerName = wh.name;
        ownerType = 'warehouse';
      } else {
        const u = mockDb.users.find(usr => usr.id === s.owner_id);
        if (u) {
          ownerName = `${u.name} (${u.role.replaceAll('_', ' ').toUpperCase()})`;
          ownerType = u.role;
        }
      }

      return {
        ...s,
        product,
        owner_name: ownerName,
        owner_type: ownerType
      };
    });
    return res.json(resolved);
  }
});

// Full Stock Transfers History (Super Admin & Store Admin & FSM)
app.get('/api/stock/transfers', async (req, res) => {
  const { from_id, to_id, status, user_id } = req.query;

  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('stock_transfers')
        .select('*, product:products(name, sku, unit)');
      if (from_id) query = query.eq('from_id', from_id);
      if (to_id) query = query.eq('to_id', to_id);
      if (status && status !== 'all') query = query.eq('status', status);
      if (user_id) query = query.or(`from_id.eq.${user_id},to_id.eq.${user_id}`);

      const { data, error } = await query.order('created_at', { ascending: false });
      if (error) throw error;

      const { data: users } = await supabase.from('users').select('id, name');
      const { data: warehouses } = await supabase.from('warehouses').select('id, name');
      const nameMap = new Map([
        ...(users || []).map(u => [u.id, u.name]),
        ...(warehouses || []).map(w => [w.id, w.name])
      ]);

      const resolved = data.map(t => ({
        ...t,
        from_name: nameMap.get(t.from_id) || 'Unknown Source',
        to_name: nameMap.get(t.to_id) || 'Unknown Destination'
      }));

      return res.json(resolved);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const nameMap = new Map([
      ...mockDb.users.map(u => [u.id, u.name]),
      ...mockDb.warehouses.map(w => [w.id, w.name])
    ]);

    let list = [...mockDb.transfers];
    if (from_id) list = list.filter(t => t.from_id === from_id);
    if (to_id) list = list.filter(t => t.to_id === to_id);
    if (status && status !== 'all') list = list.filter(t => t.status === status);
    if (user_id) list = list.filter(t => t.from_id === user_id || t.to_id === user_id);

    const resolved = list.map(t => {
      const product = mockDb.products.find(p => p.id === t.product_id);
      return {
        ...t,
        product,
        from_name: nameMap.get(t.from_id) || 'Unknown Source',
        to_name: nameMap.get(t.to_id) || 'Unknown Destination'
      };
    }).sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    return res.json(resolved);
  }
});

// Low-Stock Alerts across warehouses or specific warehouse
app.get('/api/stock/alerts', async (req, res) => {
  const { warehouse_id, owner_id } = req.query;
  const targetOwner = warehouse_id || owner_id;

  if (isSupabaseConfigured) {
    try {
      const { data: products, error: pErr } = await supabase.from('products').select('*');
      if (pErr) throw pErr;
      let stockQuery = supabase.from('stocks').select('*');
      if (targetOwner) stockQuery = stockQuery.eq('owner_id', targetOwner);
      const { data: stocks, error: sErr } = await stockQuery;
      if (sErr) throw sErr;

      const alerts = [];
      for (const prod of products) {
        const totalQty = (stocks || [])
          .filter(s => s.product_id === prod.id)
          .reduce((sum, s) => sum + s.quantity, 0);
        const threshold = prod.min_stock_alert || 20;
        if (totalQty < threshold) {
          alerts.push({
            product: prod,
            total_quantity: totalQty,
            threshold,
            deficit: threshold - totalQty
          });
        }
      }
      return res.json(alerts);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const alerts = [];
    for (const prod of mockDb.products) {
      let stockPool = mockDb.stocks;
      if (targetOwner) {
        stockPool = stockPool.filter(s => s.owner_id === targetOwner);
      }
      const totalQty = stockPool
        .filter(s => s.product_id === prod.id)
        .reduce((sum, s) => sum + s.quantity, 0);
      const threshold = prod.min_stock_alert || 20;
      if (totalQty < threshold) {
        alerts.push({
          product: prod,
          total_quantity: totalQty,
          threshold,
          deficit: threshold - totalQty
        });
      }
    }
    return res.json(alerts);
  }
});

// Get stock levels for a specific owner (warehouse or user)
app.get('/api/stock/:owner_id', async (req, res) => {
  const { owner_id } = req.params;

  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('stocks').select('*, product:products(name, sku, unit)').eq('owner_id', owner_id);
      if (error) throw error;
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const stockList = mockDb.stocks.filter(s => s.owner_id === owner_id).map(s => {
      const product = mockDb.products.find(p => p.id === s.product_id);
      return { ...s, product };
    });
    return res.json(stockList);
  }
});

// --- CUSTOMERS & DISTRIBUTORS DIRECTORY ---
app.get('/api/customers', async (req, res) => {
  const { customer_type, salesman_id } = req.query;
  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('customers').select('*');
      if (customer_type && customer_type !== 'all') {
        query = query.eq('customer_type', customer_type);
      }
      if (salesman_id && salesman_id !== 'all') {
        query = query.eq('created_by', salesman_id);
      }
      const { data, error } = await query.order('created_at', { ascending: false });
      if (!error && data) return res.json(data);
    } catch (err) {
      console.warn('customers fetch notice, using in-memory directory:', err.message);
    }
  }

  let list = mockDb.customers || [];
  if (customer_type && customer_type !== 'all') {
    list = list.filter(c => c.customer_type === customer_type);
  }
  if (salesman_id && salesman_id !== 'all') {
    const soldCustomerIds = (mockDb.sales || [])
      .filter(s => s.salesman_id === salesman_id)
      .map(s => s.customer_id)
      .filter(Boolean);
    list = list.filter(c => c.created_by === salesman_id || soldCustomerIds.includes(c.id));
  }
  return res.json(list);
});

app.post('/api/customers', async (req, res) => {
  const { name, phone, email, address, customer_type, referral_code, created_by } = req.body;
  if (!name) return res.status(400).json({ error: 'Customer name is required' });

  const generatedRef = referral_code || `${name.replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 6)}${Math.floor(100 + Math.random() * 900)}`;

  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('customers').insert([{
        name, phone: phone || '', email: email || '', address: address || '', customer_type: customer_type || 'retail', referral_code: generatedRef, created_by: created_by || null
      }]).select().single();
      if (!error && data) {
        return res.status(201).json(data);
      }
    } catch (err) {
      console.warn('customers insert notice, falling back to in-memory store:', err.message);
    }
  }

  const newCust = {
    id: `c_${Date.now()}`,
    name,
    phone: phone || '',
    email: email || '',
    address: address || '',
    customer_type: customer_type || 'retail',
    referral_code: generatedRef,
    referred_by: null,
    created_by: created_by || null,
    created_at: new Date()
  };
  if (!mockDb.customers) mockDb.customers = [];
  mockDb.customers.unshift(newCust);
  return res.status(201).json(newCust);
});

// --- WORKFORCE REFERRAL & COMMISSION MANAGEMENT ---

// Get workforce referral rule configuration
app.get('/api/referrals/rules', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('referral_rules').select('*').maybeSingle();
      if (!error && data) {
        return res.json({
          id: data.id || 'rr_workforce_default',
          commission_per_bottle: Number(data.commission_per_bottle || data.bonus_value || 1.00),
          min_sales_quota: Number(data.min_sales_quota || 5),
          is_quota_condition_active: data.is_quota_condition_active !== undefined ? Boolean(data.is_quota_condition_active) : true,
          is_active: data.is_active !== undefined ? Boolean(data.is_active) : true,
          eligible_roles: ['store_admin', 'field_sales_manager', 'salesman'],
          bonus_value: Number(data.commission_per_bottle || data.bonus_value || 1.00),
          min_purchase_amount: Number(data.min_sales_quota || 5)
        });
      }
    } catch (_) {}
  }
  return res.json(mockDb.referral_rules);
});

// Update workforce referral rule configuration (Super Admin)
app.post('/api/referrals/rules', async (req, res) => {
  const {
    commission_per_bottle,
    min_sales_quota,
    is_quota_condition_active,
    is_active,
    bonus_value,
    min_purchase_amount,
    admin_id,
    admin_name
  } = req.body;

  const rate = parseFloat(commission_per_bottle !== undefined ? commission_per_bottle : (bonus_value !== undefined ? bonus_value : 1.00));
  const quota = parseInt(min_sales_quota !== undefined ? min_sales_quota : (min_purchase_amount !== undefined ? min_purchase_amount : 5));
  const quotaActive = is_quota_condition_active !== undefined ? Boolean(is_quota_condition_active) : true;
  const programActive = is_active !== undefined ? Boolean(is_active) : true;

  const ruleData = {
    id: 'rr_workforce_default',
    commission_per_bottle: rate,
    min_sales_quota: quota,
    is_quota_condition_active: quotaActive,
    is_active: programActive,
    eligible_roles: ['store_admin', 'field_sales_manager', 'salesman'],
    // Backward compatibility fields for legacy UI
    bonus_type: 'flat',
    bonus_value: rate,
    min_purchase_amount: quota,
    updated_at: new Date()
  };

  mockDb.referral_rules = ruleData;

  // Re-evaluate pending commissions against updated quota and status
  if (mockDb.workforceCommissions) {
    mockDb.workforceCommissions.forEach(comm => {
      if (comm.status !== 'paid') {
        const referrerSales = (mockDb.sales || []).filter(s => s.salesman_id === comm.referrer_id);
        const referrerBottlesToday = referrerSales.reduce((sum, s) => sum + (Number(s.quantity) || 0), 0);
        const isQualified = !quotaActive || (referrerBottlesToday >= quota);
        comm.status = isQualified ? 'unlocked' : 'quota_pending';
        comm.rate_per_bottle = rate;
        comm.commission_amount = (Number(comm.bottles_sold) || 0) * rate;
      }
    });
  }

  await logAudit(
    admin_id || 'u1',
    admin_name || 'Super Admin',
    'UPDATE_REFERRAL_RULES',
    'referral_rules',
    ruleData.id,
    `Updated workforce referral rules: ₹${rate}/bottle, min quota: ${quota} btls, quota gate: ${quotaActive ? 'ON' : 'OFF'}`
  );

  return res.json(mockDb.referral_rules);
});

// Helper to build workforce referral tree
function buildWorkforceTree() {
  const users = [...(mockDb.users || [])];
  const sales = [...(mockDb.sales || [])];
  const commissions = [...(mockDb.workforceCommissions || [])];
  const rules = mockDb.referral_rules || { commission_per_bottle: 1.00, min_sales_quota: 5, is_quota_condition_active: true };

  // Calculate sold bottles today per user
  const salesByUser = {};
  sales.forEach(s => {
    if (s.salesman_id) {
      salesByUser[s.salesman_id] = (salesByUser[s.salesman_id] || 0) + (Number(s.quantity) || 0);
    }
  });

  // Calculate commissions per referrer
  const unlockedByUser = {};
  const pendingByUser = {};
  commissions.forEach(c => {
    if (c.status === 'unlocked' || c.status === 'paid') {
      unlockedByUser[c.referrer_id] = (unlockedByUser[c.referrer_id] || 0) + (Number(c.commission_amount) || 0);
    } else if (c.status === 'quota_pending') {
      pendingByUser[c.referrer_id] = (pendingByUser[c.referrer_id] || 0) + (Number(c.commission_amount) || 0);
    }
  });

  const quota = rules.min_sales_quota || 5;
  const isQuotaActive = rules.is_quota_condition_active !== false;

  // Build node object for a user
  function formatNode(u) {
    const bottlesSold = salesByUser[u.id] || 0;
    const isQualified = !isQuotaActive || (bottlesSold >= quota);
    const unlocked = unlockedByUser[u.id] || 0;
    const pending = pendingByUser[u.id] || 0;

    const directRefUsers = users.filter(usr => usr.referrer_id === u.id);

    return {
      id: u.id,
      name: u.name,
      role: u.role,
      email: u.email,
      referrer_id: u.referrer_id || null,
      bottles_sold_today: bottlesSold,
      min_quota: quota,
      is_qualified: isQualified,
      unlocked_commission: unlocked,
      pending_commission: pending,
      downline_count: directRefUsers.length,
      children: directRefUsers.map(child => formatNode(child))
    };
  }

  // Find root salesmen (salesmen that are not referred by any other salesman)
  const rootSalesmen = users.filter(u => u.role === 'salesman' && !u.referrer_id);

  // If no root salesman found, return all salesmen that have referrals or sales
  const treeNodes = rootSalesmen.length > 0 ? rootSalesmen.map(formatNode) : users.filter(u => u.role === 'salesman').slice(0, 1).map(formatNode);

  return {
    rules,
    tree: treeNodes,
    total_salesmen: users.filter(u => u.role === 'salesman').length
  };
}

// Get full workforce referral tree
app.get('/api/referrals/tree', (req, res) => {
  return res.json(buildWorkforceTree());
});

// Get all workforce referral commissions (Ledger)
app.get('/api/referrals', async (req, res) => {
  const commissions = mockDb.workforceCommissions || [];
  const enriched = commissions.map(c => {
    return {
      ...c,
      referrer_name: c.referrer_name || ((mockDb.users || []).find(u => u.id === c.referrer_id)?.name) || 'Referrer',
      referred_name: c.seller_name || ((mockDb.users || []).find(u => u.id === c.seller_id)?.name) || 'Salesman'
    };
  });
  return res.json(enriched);
});

// Process / approve referral payout
app.post('/api/referrals/:id/payout', async (req, res) => {
  const { id } = req.params;
  const { admin_id, admin_name } = req.body;

  const comm = (mockDb.workforceCommissions || []).find(c => c.id === id);
  if (!comm) {
    // Check fallback referrals
    const legacy = (mockDb.referrals || []).find(r => r.id === id);
    if (legacy) {
      legacy.status = 'paid';
      legacy.paid_at = new Date();
      return res.json({ message: 'Payout marked as paid', referral: legacy });
    }
    return res.status(404).json({ error: 'Referral commission record not found' });
  }

  comm.status = 'paid';
  comm.paid_at = new Date().toISOString();

  await logAudit(
    admin_id || 'u1',
    admin_name || 'Super Admin',
    'REFERRAL_PAYOUT',
    'workforce_commissions',
    id,
    `Disbursed referral commission payout of ₹${comm.commission_amount} to ${comm.referrer_name}`
  );

  return res.json({ message: 'Payout marked as paid', referral: comm });
});

// --- AUDIT TRAIL API ---

// View audit logs
app.get('/api/audit-logs', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data, error } = await supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(100);
      if (error) throw error;
      return res.json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    return res.json(mockDb.audit_logs);
  }
});

// --- SYSTEM SUMMARY & REPORTS ---

// Executive Summary for Dashboard
app.get('/api/reports/summary', async (req, res) => {
  if (isSupabaseConfigured) {
    try {
      const { data: sales } = await supabase.from('sales').select('amount, quantity, created_at');
      const { data: users } = await supabase.from('users').select('id');
      const { data: products } = await supabase.from('products').select('id');
      const { data: warehouses } = await supabase.from('warehouses').select('id');
      const { data: referrals } = await supabase.from('referrals').select('status, bonus_amount');
      const { data: stocks } = await supabase.from('stocks').select('quantity, product_id');
      const { data: settlements } = await supabase.from('settlements').select('*');

      const totalRevenue = (sales || []).reduce((acc, s) => acc + (parseFloat(s.amount) || 0), 0);
      const pendingReferralPayouts = (referrals || []).filter(r => r.status === 'pending').reduce((acc, r) => acc + (parseFloat(r.bonus_amount) || 0), 0);

      const totalStock = (stocks || []).reduce((acc, s) => acc + (parseInt(s.quantity) || 0), 0);

      const todayStr = new Date().toISOString().slice(0, 10);
      const todaySales = (sales || []).filter(s => s.created_at && new Date(s.created_at).toISOString().slice(0, 10) === todayStr);
      const todaySalesAmount = todaySales.reduce((acc, s) => acc + (parseFloat(s.amount) || 0), 0);
      const todaySalesBottles = todaySales.reduce((acc, s) => acc + (parseInt(s.quantity) || 0), 0);
      const todaySalesCount = todaySales.length;

      const pendingSettlements = (settlements || []).filter(s => s.status !== 'tally_zero' && s.status !== 'settled');
      const pendingSettlementCount = pendingSettlements.length;
      const pendingSettlementAmount = pendingSettlements.reduce((acc, s) => acc + (parseFloat(s.difference) || 0), 0);

      return res.json({
        totalRevenue,
        userCount: users?.length || 0,
        productCount: products?.length || 0,
        warehouseCount: warehouses?.length || 0,
        pendingReferralPayouts,
        totalStock,
        todaySalesAmount,
        todaySalesBottles,
        todaySalesCount,
        pendingSettlementCount,
        pendingSettlementAmount
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const totalRevenue = (mockDb.sales || []).reduce((acc, s) => acc + (parseFloat(s.amount) || 0), 0);
    const pendingReferralPayouts = (mockDb.referrals || []).filter(r => r.status === 'pending').reduce((acc, r) => acc + (parseFloat(r.bonus_amount) || 0), 0);

    const totalStock = (mockDb.stocks || []).reduce((acc, s) => acc + (parseInt(s.quantity) || 0), 0);

    const todayStr = new Date().toISOString().slice(0, 10);
    const todaySales = (mockDb.sales || []).filter(s => s.created_at && new Date(s.created_at).toISOString().slice(0, 10) === todayStr);
    const todaySalesAmount = todaySales.reduce((acc, s) => acc + (parseFloat(s.amount) || 0), 0);
    const todaySalesBottles = todaySales.reduce((acc, s) => acc + (parseInt(s.quantity) || 0), 0);
    const todaySalesCount = todaySales.length;

    const pendingSettlements = (mockDb.settlements || []).filter(s => s.status !== 'tally_zero' && s.status !== 'settled');
    const pendingSettlementCount = pendingSettlements.length;
    const pendingSettlementAmount = pendingSettlements.reduce((acc, s) => acc + (parseFloat(s.difference) || 0), 0);

    return res.json({
      totalRevenue,
      userCount: (mockDb.users || []).length,
      productCount: (mockDb.products || []).length,
      warehouseCount: (mockDb.warehouses || []).length,
      pendingReferralPayouts,
      totalStock,
      todaySalesAmount,
      todaySalesBottles,
      todaySalesCount,
      pendingSettlementCount,
      pendingSettlementAmount
    });
  }
});

// --- SALES ---

// Helper function to process workforce referral commissions and unlock quota conditions
async function processWorkforceCommissionForSale(salesman_id, saleQty, saleId) {
  if (!salesman_id || saleQty <= 0) return;

  const users = mockDb.users || [];
  const seller = users.find(u => u.id === salesman_id);
  const rules = mockDb.referral_rules || { commission_per_bottle: 1.00, min_sales_quota: 5, is_quota_condition_active: true };

  // 1. If seller has a direct referrer, calculate downline commission for that referrer
  if (seller && seller.referrer_id && rules.is_active !== false) {
    const referrer = users.find(u => u.id === seller.referrer_id);
    if (referrer) {
      const rate = Number(rules.commission_per_bottle) || 1.00;
      const quota = Number(rules.min_sales_quota) || 5;
      const isQuotaActive = rules.is_quota_condition_active !== false;

      // Calculate referrer's sales today
      const referrerSales = (mockDb.sales || []).filter(s => s.salesman_id === seller.referrer_id);
      const referrerBottlesToday = referrerSales.reduce((sum, s) => sum + (Number(s.quantity) || 0), 0);
      const isQualified = !isQuotaActive || (referrerBottlesToday >= quota);
      const commAmount = saleQty * rate;

      const newComm = {
        id: `w_comm_${Date.now()}_${Math.floor(100 + Math.random() * 900)}`,
        referrer_id: seller.referrer_id,
        referrer_name: referrer.name,
        seller_id: seller.id,
        seller_name: seller.name,
        bottles_sold: saleQty,
        rate_per_bottle: rate,
        commission_amount: commAmount,
        status: isQualified ? 'unlocked' : 'quota_pending',
        referrer_sales_today: referrerBottlesToday,
        min_quota_required: quota,
        sale_id: saleId,
        created_at: new Date().toISOString(),
        paid_at: null
      };

      if (!mockDb.workforceCommissions) mockDb.workforceCommissions = [];
      mockDb.workforceCommissions.unshift(newComm);

      if (isSupabaseConfigured) {
        try {
          await supabase.from('workforce_commissions').insert([{
            referrer_id: seller.referrer_id,
            referrer_name: referrer.name,
            seller_id: seller.id,
            seller_name: seller.name,
            sale_id: saleId || null,
            bottles_sold: saleQty,
            rate_per_bottle: rate,
            commission_amount: commAmount,
            status: newComm.status,
            referrer_sales_today: referrerBottlesToday,
            min_quota_required: quota
          }]);
        } catch (e) {
          console.warn('workforce_commissions Supabase insert notice:', e.message);
        }
      }
    }
  }

  // 2. Check if this sale allows the seller themselves to meet the quota and unlocks their pending commissions
  const sellerSales = (mockDb.sales || []).filter(s => s.salesman_id === salesman_id);
  const sellerBottlesToday = sellerSales.reduce((sum, s) => sum + (Number(s.quantity) || 0), 0);
  const quota = Number(rules.min_sales_quota) || 5;

  if (sellerBottlesToday >= quota && mockDb.workforceCommissions) {
    mockDb.workforceCommissions.forEach(comm => {
      if (comm.referrer_id === salesman_id && comm.status === 'quota_pending') {
        comm.status = 'unlocked';
      }
    });

    if (isSupabaseConfigured) {
      try {
        await supabase.from('workforce_commissions')
          .update({ status: 'unlocked' })
          .eq('referrer_id', salesman_id)
          .eq('status', 'quota_pending');
      } catch (e) {
        console.warn('workforce_commissions unlock notice:', e.message);
      }
    }
  }
}

// Log sale (Salesman Field Sales & Store Admin Direct Retail / Distributor Bulk Sales & FSM Direct Retail)
app.post('/api/sales', async (req, res) => {
  const {
    salesman_id,
    warehouse_id,
    customer_id,
    customer_name,
    customer_phone,
    customer_email,
    customer_address,
    customer_type = 'retail',
    product_id,
    quantity,
    amount,
    payment_method
  } = req.body;

  if (!product_id || !quantity || !amount || !payment_method) {
    return res.status(400).json({ error: 'product_id, quantity, amount, and payment_method are required' });
  }

  // Stock source: warehouse_id if direct warehouse sale, otherwise salesman_id
  const stockOwnerId = warehouse_id || salesman_id;
  if (!stockOwnerId) {
    return res.status(400).json({ error: 'Either warehouse_id or salesman_id must be provided' });
  }

  const saleQty = parseInt(quantity);

  if (isSupabaseConfigured) {
    try {
      // Distributor sales restriction: FSM and Salesman cannot sell to distributors
      if (customer_type === 'distributor' && salesman_id) {
        const { data: sellerUser } = await supabase.from('users').select('role').eq('id', salesman_id).maybeSingle();
        if (sellerUser && (sellerUser.role === 'field_sales_manager' || sellerUser.role === 'salesman')) {
          return res.status(403).json({ error: 'Field Sales Managers and Salesmen cannot sell to distributors. Distributor sales are restricted to Store Admin / Super Admin.' });
        }
      }

      // Check stock
      let { data: currentStock, error: stockErr } = await supabase.from('stocks')
        .select('*')
        .eq('owner_id', stockOwnerId)
        .eq('product_id', product_id)
        .maybeSingle();

      if (stockErr || !currentStock) {
        const mockItem = mockDb.stocks.find(s => s.owner_id === stockOwnerId && s.product_id === product_id);
        const seedQty = mockItem ? mockItem.quantity : 25;
        try {
          const { data: newStock } = await supabase.from('stocks').insert([{
            owner_id: stockOwnerId,
            product_id,
            quantity: Math.max(seedQty, saleQty + 10)
          }]).select().maybeSingle();
          currentStock = newStock || { id: `stk_${Date.now()}`, owner_id: stockOwnerId, product_id, quantity: Math.max(seedQty, saleQty + 10) };
        } catch (_) {
          currentStock = { id: `stk_${Date.now()}`, owner_id: stockOwnerId, product_id, quantity: Math.max(seedQty, saleQty + 10) };
        }
      }

      if (currentStock.quantity < saleQty) {
        return res.status(400).json({ error: 'Insufficient stock at warehouse/seller' });
      }

      // Handle customer inline registration if new customer name is passed (customers have NO referral codes)
      let finalCustomerId = customer_id;
      if (!finalCustomerId && customer_name) {
        const { data: newCust } = await supabase.from('customers').insert([{
          name: customer_name,
          phone: customer_phone || '',
          email: customer_email || '',
          address: customer_address || '',
          customer_type: customer_type || 'retail',
          created_by: salesman_id || null
        }]).select().single();
        if (newCust) finalCustomerId = newCust.id;
      }

      // Deduct stock
      await supabase.from('stocks')
        .update({ quantity: currentStock.quantity - saleQty })
        .eq('id', currentStock.id);

      // Create sale record with adaptive fallback
      let saleData = null;
      const { data: fullSale, error: saleErr } = await supabase.from('sales').insert([{
        warehouse_id: warehouse_id || null,
        salesman_id: salesman_id || null,
        customer_id: finalCustomerId || null,
        customer_type: customer_type || 'retail',
        product_id,
        quantity: saleQty,
        amount,
        payment_method
      }]).select().single();

      if (!saleErr && fullSale) {
        saleData = fullSale;
      } else {
        console.warn('Full sales insert notice, retrying with core schema:', saleErr ? saleErr.message : 'Unknown error');
        const { data: coreSale, error: coreErr } = await supabase.from('sales').insert([{
          salesman_id: salesman_id || null,
          product_id,
          quantity: saleQty,
          amount,
          payment_method
        }]).select().single();

        if (coreErr) throw coreErr;
        saleData = {
          ...coreSale,
          warehouse_id: warehouse_id || null,
          customer_id: finalCustomerId || null,
          customer_type: customer_type || 'retail'
        };
      }

      // Process workforce referral commission for this sale
      await processWorkforceCommissionForSale(salesman_id, saleQty, saleData.id);

      const roleLabel = warehouse_id ? 'Store Admin' : 'Seller';
      await logAudit(salesman_id, roleLabel, 'SALE_COMPLETED', 'sales', saleData.id, `Completed ${customer_type || 'retail'} sale of ${saleQty} units for ₹${amount} (${payment_method})`);
      return res.status(201).json(saleData);
    } catch (err) {
      console.warn('Supabase sale insert failed, falling back to mockDb:', err.message);
      const currentStock = mockDb.stocks.find(s => s.owner_id === stockOwnerId && s.product_id === product_id);
      if (currentStock) currentStock.quantity = Math.max(0, currentStock.quantity - saleQty);

      let finalCustomerId = customer_id;
      if (!finalCustomerId && customer_name) {
        const newCust = {
          id: `c_${Date.now()}`,
          name: customer_name,
          phone: customer_phone || '',
          email: customer_email || '',
          address: customer_address || '',
          customer_type: customer_type || 'retail',
          created_by: salesman_id || null,
          created_at: new Date()
        };
        mockDb.customers.push(newCust);
        finalCustomerId = newCust.id;
      }

      const newSale = {
        id: `sale_${Date.now()}`,
        warehouse_id: warehouse_id || null,
        salesman_id: salesman_id || null,
        customer_id: finalCustomerId || null,
        customer_type: customer_type || 'retail',
        product_id,
        quantity: saleQty,
        amount,
        payment_method,
        created_at: new Date().toISOString()
      };
      mockDb.sales.unshift(newSale);

      await processWorkforceCommissionForSale(salesman_id, saleQty, newSale.id);

      const roleLabel = warehouse_id ? 'Store Admin' : 'Seller';
      await logAudit(salesman_id, roleLabel, 'SALE_COMPLETED', 'sales', newSale.id, `Completed ${customer_type || 'retail'} sale of ${saleQty} units for ₹${amount} (${payment_method})`);
      return res.status(201).json(newSale);
    }
  } else {
    // Distributor sales restriction in mock mode
    if (customer_type === 'distributor' && salesman_id) {
      const sellerUser = mockDb.users.find(u => u.id === salesman_id);
      if (sellerUser && (sellerUser.role === 'field_sales_manager' || sellerUser.role === 'salesman')) {
        return res.status(403).json({ error: 'Field Sales Managers and Salesmen cannot sell to distributors. Distributor sales are restricted to Store Admin / Super Admin.' });
      }
    }

    const currentStock = mockDb.stocks.find(s => s.owner_id === stockOwnerId && s.product_id === product_id);
    if (!currentStock || currentStock.quantity < saleQty) {
      return res.status(400).json({ error: 'Insufficient stock at warehouse/seller' });
    }

    currentStock.quantity -= saleQty;

    let finalCustomerId = customer_id;
    if (!finalCustomerId && customer_name) {
      const newCust = {
        id: `c_${Date.now()}`,
        name: customer_name,
        phone: customer_phone || '',
        email: customer_email || '',
        address: customer_address || '',
        customer_type: customer_type || 'retail',
        referred_by: null,
        created_by: salesman_id || null,
        created_at: new Date()
      };
      mockDb.customers.push(newCust);
      finalCustomerId = newCust.id;
    }

    const newSale = {
      id: `sale_${Date.now()}`,
      warehouse_id: warehouse_id || null,
      salesman_id: salesman_id || null,
      customer_id: finalCustomerId || null,
      customer_type: customer_type || 'retail',
      product_id,
      quantity: saleQty,
      amount,
      payment_method,
      created_at: new Date()
    };
    mockDb.sales.unshift(newSale);

    // Process workforce referral commission for this sale
    await processWorkforceCommissionForSale(salesman_id, saleQty, newSale.id);

    const roleLabel = warehouse_id ? 'Store Admin' : 'Seller';
    await logAudit(salesman_id, roleLabel, 'SALE_COMPLETED', 'sales', newSale.id, `Completed ${customer_type || 'retail'} sale of ${saleQty} units for ₹${amount} (${payment_method})`);
    return res.status(201).json(newSale);
  }
});

// Team Oversight (Field Sales Manager: supervised salesmen, live stock, sales performance, aggregate KPIs)
app.get('/api/team/:fsm_id', async (req, res) => {
  const { fsm_id } = req.params;

  if (isSupabaseConfigured) {
    try {
      const { data: salesmen, error: sErr } = await supabase.from('users')
        .select('*')
        .eq('parent_id', fsm_id)
        .eq('role', 'salesman');
      if (sErr) throw sErr;

      const salesmanIds = (salesmen || []).map(s => s.id);

      let teamStocks = [];
      if (salesmanIds.length > 0) {
        const { data: stData } = await supabase.from('stocks')
          .select('*, product:products(name, sku, unit, min_stock_alert)')
          .in('owner_id', salesmanIds);
        teamStocks = stData || [];
      }

      let teamSales = [];
      if (salesmanIds.length > 0) {
        const { data: slData } = await supabase.from('sales')
          .select('*')
          .in('salesman_id', salesmanIds);
        teamSales = slData || [];
      }

      const salesmenDetails = (salesmen || []).map(sm => {
        const stocks = teamStocks.filter(st => st.owner_id === sm.id);
        const sales = teamSales.filter(sl => sl.salesman_id === sm.id);
        const totalQtySold = sales.reduce((acc, sl) => acc + (sl.quantity || 0), 0);
        const totalRevenue = sales.reduce((acc, sl) => acc + (parseFloat(sl.amount) || 0), 0);
        const transactionCount = sales.length;
        const hasLowStock = stocks.some(st => st.quantity < (st.product?.min_stock_alert || 10));

        return {
          ...sm,
          stocks,
          total_qty_sold: totalQtySold,
          total_revenue: totalRevenue,
          transaction_count: transactionCount,
          has_low_stock: hasLowStock
        };
      });

      const totalTeamRevenue = salesmenDetails.reduce((acc, sm) => acc + sm.total_revenue, 0);
      const totalTeamUnits = salesmenDetails.reduce((acc, sm) => acc + sm.total_qty_sold, 0);
      const totalTeamTransactions = salesmenDetails.reduce((acc, sm) => acc + sm.transaction_count, 0);
      const totalActiveStock = teamStocks.reduce((acc, st) => acc + (st.quantity || 0), 0);

      return res.json({
        fsm_id,
        team_kpis: {
          total_salesmen: salesmenDetails.length,
          total_team_revenue: totalTeamRevenue,
          total_team_units: totalTeamUnits,
          total_team_transactions: totalTeamTransactions,
          total_active_stock: totalActiveStock
        },
        salesmen: salesmenDetails
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  } else {
    const salesmen = mockDb.users.filter(u => u.parent_id === fsm_id && u.role === 'salesman');
    const salesmenDetails = salesmen.map(sm => {
      const stocks = mockDb.stocks
        .filter(st => st.owner_id === sm.id)
        .map(st => ({
          ...st,
          product: mockDb.products.find(p => p.id === st.product_id)
        }));
      const sales = mockDb.sales.filter(sl => sl.salesman_id === sm.id);
      const totalQtySold = sales.reduce((acc, sl) => acc + (sl.quantity || 0), 0);
      const totalRevenue = sales.reduce((acc, sl) => acc + (parseFloat(sl.amount) || 0), 0);
      const transactionCount = sales.length;
      const hasLowStock = stocks.some(st => st.quantity < (st.product?.min_stock_alert || 10));

      return {
        ...sm,
        stocks,
        total_qty_sold: totalQtySold,
        total_revenue: totalRevenue,
        transaction_count: transactionCount,
        has_low_stock: hasLowStock
      };
    });

    const totalTeamRevenue = salesmenDetails.reduce((acc, sm) => acc + sm.total_revenue, 0);
    const totalTeamUnits = salesmenDetails.reduce((acc, sm) => acc + sm.total_qty_sold, 0);
    const totalTeamTransactions = salesmenDetails.reduce((acc, sm) => acc + sm.transaction_count, 0);
    const totalActiveStock = salesmenDetails.reduce((acc, sm) => acc + sm.stocks.reduce((stAcc, st) => stAcc + st.quantity, 0), 0);

    return res.json({
      fsm_id,
      team_kpis: {
        total_salesmen: salesmenDetails.length,
        total_team_revenue: totalTeamRevenue,
        total_team_units: totalTeamUnits,
        total_team_transactions: totalTeamTransactions,
        total_active_stock: totalActiveStock
      },
      salesmen: salesmenDetails
    });
  }
});

// Helper to filter and map sales reports
function resolveSalesList(list, query) {
  const { salesman_id, fsm_id, warehouse_id, product_id, customer_id, payment_method, customer_type, start_date, end_date, has_referral } = query;
  let res = [...list];

  if (fsm_id) {
    const teamSalesmen = (mockDb.users || []).filter(u => u.parent_id === fsm_id).map(u => u.id);
    const allowedIds = [fsm_id, ...teamSalesmen];
    res = res.filter(s => allowedIds.includes(s.salesman_id));
  } else if (salesman_id && salesman_id !== 'all') {
    res = res.filter(s => s.salesman_id === salesman_id);
  }

  if (warehouse_id && warehouse_id !== 'all') res = res.filter(s => s.warehouse_id === warehouse_id);
  if (product_id && product_id !== 'all') res = res.filter(s => s.product_id === product_id);
  if (customer_id && customer_id !== 'all') res = res.filter(s => s.customer_id === customer_id);
  if (payment_method && payment_method !== 'all') res = res.filter(s => s.payment_method === payment_method);
  if (customer_type && customer_type !== 'all') res = res.filter(s => (s.customer_type || 'retail') === customer_type);
  if (start_date) res = res.filter(s => new Date(s.created_at) >= new Date(start_date));
  if (end_date) res = res.filter(s => new Date(s.created_at) <= new Date(end_date));
  if (has_referral === 'true') res = res.filter(s => s.referral_code && s.referral_code.length > 0);

  return res.map(s => {
    const salesman = (mockDb.users || []).find(u => u.id === s.salesman_id) || { name: 'Seller', role: 'salesman' };
    const product = (mockDb.products || []).find(p => p.id === s.product_id) || { name: 'Product', sku: 'SKU' };
    const customer = (mockDb.customers || []).find(c => c.id === s.customer_id) || { name: s.customer_name || 'Customer', phone: s.customer_phone || '' };
    return { ...s, salesman, product, customer };
  }).sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

// Sales Reports with Multi-dimensional Filtering
app.get('/api/sales/report', async (req, res) => {
  const { salesman_id, fsm_id, warehouse_id, product_id, customer_id, payment_method, customer_type, start_date, end_date, has_referral } = req.query;

  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('sales').select('*');
      if (fsm_id) {
        const { data: smData } = await supabase.from('users').select('id').eq('parent_id', fsm_id);
        const allowedIds = [fsm_id, ...(smData || []).map(s => s.id)];
        query = query.in('salesman_id', allowedIds);
      } else if (salesman_id && salesman_id !== 'all') {
        query = query.eq('salesman_id', salesman_id);
      }

      if (warehouse_id && warehouse_id !== 'all') query = query.eq('warehouse_id', warehouse_id);
      if (product_id && product_id !== 'all') query = query.eq('product_id', product_id);
      if (customer_id && customer_id !== 'all') query = query.eq('customer_id', customer_id);
      if (payment_method && payment_method !== 'all') query = query.eq('payment_method', payment_method);
      if (customer_type && customer_type !== 'all') query = query.eq('customer_type', customer_type);
      if (start_date) query = query.gte('created_at', start_date);
      if (end_date) query = query.lte('created_at', end_date);
      if (has_referral === 'true') query = query.not('referral_code', 'is', null);

      const { data: salesData, error } = await query.order('created_at', { ascending: false });
      if (!error && salesData && salesData.length > 0) {
        const { data: users } = await supabase.from('users').select('id, name, role');
        const { data: products } = await supabase.from('products').select('id, name, sku, category');
        const userMap = new Map((users || []).map(u => [u.id, u]));
        const prodMap = new Map((products || []).map(p => [p.id, p]));

        const enriched = salesData.map(s => ({
          ...s,
          salesman: userMap.get(s.salesman_id) || (mockDb.users.find(u => u.id === s.salesman_id)) || { name: 'Seller', role: 'seller' },
          product: prodMap.get(s.product_id) || (mockDb.products.find(p => p.id === s.product_id)) || { name: 'Product', sku: 'SKU' },
          customer: (mockDb.customers || []).find(c => c.id === s.customer_id) || { name: s.customer_name || 'Retail Customer', phone: s.customer_phone || '' }
        }));
        return res.json(enriched);
      }
      return res.json(resolveSalesList(mockDb.sales || [], req.query));
    } catch (err) {
      console.warn('Supabase sales report fallback:', err.message);
      return res.json(resolveSalesList(mockDb.sales || [], req.query));
    }
  } else {
    return res.json(resolveSalesList(mockDb.sales || [], req.query));
  }
});

// --- PAYMENTS & TRANSACTIONS HISTORY (SUPER ADMIN) ---

app.get('/api/payments', async (req, res) => {
  const { type, method, status, search, start_date, end_date } = req.query;

  let allPayments = [...(mockDb.payments || [])];

  // Harvest from mockDb.sales
  const salesList = mockDb.sales || [];
  salesList.forEach(s => {
    if (!allPayments.some(p => p.reference_id === s.id)) {
      const prod = (mockDb.products || []).find(p => p.id === s.product_id);
      const cust = (mockDb.customers || []).find(c => c.id === s.customer_id);
      const user = (mockDb.users || []).find(u => u.id === s.salesman_id);
      allPayments.push({
        id: `pay_${s.id}`,
        payment_no: `PAY-SAL-${s.id.toString().slice(-5).toUpperCase()}`,
        type: 'sale',
        category: s.customer_type === 'distributor' ? 'Wholesale Bulk Sale' : 'Retail Customer Sale',
        amount: parseFloat(s.amount) || 0,
        payment_method: s.payment_method || 'online',
        status: 'completed',
        payer_name: cust?.name || s.customer_name || 'Walk-in Customer',
        payer_phone: cust?.phone || s.customer_phone || '',
        payer_type: s.customer_type || 'retail',
        collector_name: user?.name || 'Staff Member',
        collector_role: user?.role || 'salesman',
        item_description: `${s.quantity}x ${prod?.name || 'Bottles'}`,
        reference_id: s.id,
        notes: s.referral_code ? `Referral code used: ${s.referral_code}` : 'Order payment received',
        created_at: s.created_at || new Date().toISOString()
      });
    }
  });

  // Harvest from mockDb.settlements
  const stlList = mockDb.settlements || [];
  stlList.forEach(stl => {
    if (!allPayments.some(p => p.reference_id === stl.id)) {
      const u = (mockDb.users || []).find(usr => usr.id === stl.salesman_id);
      allPayments.push({
        id: `pay_${stl.id}`,
        payment_no: `PAY-STL-${stl.id.toString().slice(-5).toUpperCase()}`,
        type: 'settlement',
        category: 'Daily Cash Settlement',
        amount: parseFloat(stl.cash_collected || stl.sold_amount || 0),
        payment_method: 'cash',
        status: (stl.status === 'settled' || stl.status === 'tally_zero') ? 'completed' : 'pending',
        payer_name: u ? `${u.name} (Salesman)` : 'Salesman Deposit',
        payer_phone: u?.phone || '',
        payer_type: 'salesman',
        collector_name: 'Field Sales Manager / Depot',
        collector_role: 'manager',
        item_description: `Evening Cash Handover (${stl.bottles_sold || 0} btls sold)`,
        reference_id: stl.id,
        notes: `Difference: ₹${stl.difference || 0}`,
        created_at: stl.created_at || new Date().toISOString()
      });
    }
  });

  // Harvest from paid referrals
  const refList = mockDb.referrals || [];
  refList.filter(r => r.status === 'paid').forEach(r => {
    if (!allPayments.some(p => p.reference_id === r.id)) {
      allPayments.push({
        id: `pay_${r.id}`,
        payment_no: `PAY-REF-${r.id.toString().slice(-5).toUpperCase()}`,
        type: 'referral_payout',
        category: 'Referral Bonus Disbursement',
        amount: parseFloat(r.bonus_amount || 50),
        payment_method: 'online',
        status: 'completed',
        payer_name: 'Sanap ERP Treasury',
        payer_phone: '',
        payer_type: 'system',
        collector_name: r.referrer_name || 'Referrer Partner',
        collector_role: 'customer',
        item_description: `Referral Reward for ${r.referred_name || 'Customer'}`,
        reference_id: r.id,
        notes: 'Bonus Payout Processed',
        created_at: r.created_at || new Date().toISOString()
      });
    }
  });

  // Apply filters
  let filtered = [...allPayments];
  if (type && type !== 'all') {
    filtered = filtered.filter(p => p.type === type);
  }
  if (method && method !== 'all') {
    filtered = filtered.filter(p => p.payment_method === method);
  }
  if (status && status !== 'all') {
    filtered = filtered.filter(p => p.status === status);
  }
  if (search) {
    const q = search.toLowerCase();
    filtered = filtered.filter(p =>
      (p.payer_name && p.payer_name.toLowerCase().includes(q)) ||
      (p.payment_no && p.payment_no.toLowerCase().includes(q)) ||
      (p.collector_name && p.collector_name.toLowerCase().includes(q)) ||
      (p.item_description && p.item_description.toLowerCase().includes(q)) ||
      (p.notes && p.notes.toLowerCase().includes(q))
    );
  }
  if (start_date) {
    filtered = filtered.filter(p => new Date(p.created_at) >= new Date(start_date));
  }
  if (end_date) {
    filtered = filtered.filter(p => new Date(p.created_at) <= new Date(end_date));
  }

  // Sort descending by created_at
  filtered.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  // Compute metrics
  const totalVolume = filtered.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const totalCollected = filtered.filter(p => p.type !== 'referral_payout').reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const onlineTotal = filtered.filter(p => p.payment_method === 'online' || p.payment_method === 'upi').reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const cashTotal = filtered.filter(p => p.payment_method === 'cash').reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const payoutsTotal = filtered.filter(p => p.type === 'referral_payout').reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

  return res.json({
    summary: {
      total_volume: totalVolume,
      total_collected: totalCollected,
      online_total: onlineTotal,
      cash_total: cashTotal,
      payouts_total: payoutsTotal,
      count: filtered.length
    },
    payments: filtered
  });
});

// Record Manual Payment Entry (Super Admin)
app.post('/api/payments', async (req, res) => {
  const {
    payer_name,
    payer_phone,
    amount,
    payment_method,
    category,
    item_description,
    collector_name,
    notes,
    admin_id,
    admin_name
  } = req.body;

  if (!payer_name || !amount || !payment_method) {
    return res.status(400).json({ error: 'payer_name, amount, and payment_method are required' });
  }

  const newPay = {
    id: `pay_${Date.now()}`,
    payment_no: `PAY-MAN-${Math.floor(10000 + Math.random() * 90000)}`,
    type: 'sale',
    category: category || 'Direct Payment Adjustment',
    amount: parseFloat(amount),
    payment_method,
    status: 'completed',
    payer_name,
    payer_phone: payer_phone || '',
    payer_type: 'retail',
    collector_name: collector_name || admin_name || 'Super Admin',
    collector_role: 'super_admin',
    item_description: item_description || 'Payment receipt adjustment',
    reference_id: `rec_${Date.now()}`,
    notes: notes || 'Manually logged by Super Admin',
    created_at: new Date().toISOString()
  };

  if (!mockDb.payments) mockDb.payments = [];
  mockDb.payments.unshift(newPay);

  await logAudit(admin_id || 'u1', admin_name || 'Super Admin', 'CREATE_PAYMENT', 'payments', newPay.id, `Logged payment of ₹${amount} from ${payer_name} via ${payment_method}`);
  return res.status(201).json(newPay);
});

// --- SALESMAN REDESIGN ENDPOINTS ---

// 1. Salesman Duty Status Toggle
app.put('/api/users/:id/duty', async (req, res) => {
  const { id } = req.params;
  const { is_on_duty } = req.body;
  const user = mockDb.users.find(u => u.id === id);
  if (!user) return res.status(404).json({ error: 'User not found' });
  user.is_on_duty = Boolean(is_on_duty);
  await logAudit(id, user.name, 'TOGGLE_DUTY', 'users', id, `Salesman is now ${user.is_on_duty ? 'ON DUTY' : 'OFF DUTY'}`);
  return res.json({ success: true, is_on_duty: user.is_on_duty });
});

// 2. Salesman Today's Earnings Breakdown
app.get('/api/salesman/earnings/:salesman_id', (req, res) => {
  const { salesman_id } = req.params;
  const user = (mockDb.users || []).find(u => u.id === salesman_id);
  const todaySales = (mockDb.sales || []).filter(s => s.salesman_id === salesman_id);
  const soldBottlesToday = todaySales.reduce((sum, s) => sum + (Number(s.quantity) || 0), 0);
  const commissionRate = 30; // ₹30 per bottle base direct sale commission
  const commissionEarned = soldBottlesToday * commissionRate;

  const rules = mockDb.referral_rules || { commission_per_bottle: 1.00, min_sales_quota: 5, is_quota_condition_active: true };
  const minQuota = Number(rules.min_sales_quota) || 5;
  const isQuotaActive = rules.is_quota_condition_active !== false;
  const isQualified = !isQuotaActive || (soldBottlesToday >= minQuota);
  const bottlesNeeded = isQualified ? 0 : Math.max(0, minQuota - soldBottlesToday);

  // Workforce commissions earned by this salesman from downline referrals
  const myCommissions = (mockDb.workforceCommissions || []).filter(c => c.referrer_id === salesman_id);
  const downlineBottles = myCommissions.reduce((sum, c) => sum + (Number(c.bottles_sold) || 0), 0);
  const unlockedReferralEarned = myCommissions
    .filter(c => c.status === 'unlocked' || c.status === 'paid')
    .reduce((sum, c) => sum + (Number(c.commission_amount) || 0), 0);
  const quotaPendingReferralEarned = myCommissions
    .filter(c => c.status === 'quota_pending')
    .reduce((sum, c) => sum + (Number(c.commission_amount) || 0), 0);

  const referralRate = Number(rules.commission_per_bottle) || 1.00;
  const totalEarned = commissionEarned + unlockedReferralEarned;

  return res.json({
    salesman_id,
    salesman_name: user ? user.name : 'Salesman',
    is_on_duty: user ? (user.is_on_duty ?? true) : true,
    sold_bottles_today: soldBottlesToday,
    commission_rate: commissionRate,
    commission_earned: commissionEarned,
    // Workforce referral & qualification details
    min_sales_quota: minQuota,
    is_quota_condition_active: isQuotaActive,
    is_qualified: isQualified,
    bottles_needed_to_qualify: bottlesNeeded,
    downline_bottles_sold: downlineBottles,
    referral_rate: referralRate,
    unlocked_referral_earned: unlockedReferralEarned,
    quota_pending_referral_earned: quotaPendingReferralEarned,
    referral_earned: unlockedReferralEarned,
    referral_bottles: downlineBottles,
    total_earned: totalEarned,
    monthly_earnings: totalEarned,
    monthly_bottles_sold: soldBottlesToday
  });
});

// 3. Salesman Referrals (Get & Submit)
app.get('/api/salesman/referrals/:salesman_id', (req, res) => {
  const { salesman_id } = req.params;
  const list = (mockDb.salesmanReferrals || []).filter(r => r.referrer_id === salesman_id);
  const enriched = list.map(ref => {
    const comms = (mockDb.workforceCommissions || []).filter(
      c => c.referrer_id === salesman_id && (c.seller_id === ref.referred_salesman_id || c.seller_name === ref.full_name)
    );
    const bottlesSold = comms.reduce((sum, c) => sum + (Number(c.bottles_sold) || 0), 0);
    const commEarned = comms
      .filter(c => c.status === 'unlocked' || c.status === 'paid')
      .reduce((sum, c) => sum + (Number(c.commission_amount) || 0), 0);
    const pendingComm = comms
      .filter(c => c.status === 'quota_pending')
      .reduce((sum, c) => sum + (Number(c.commission_amount) || 0), 0);

    return {
      ...ref,
      bottles_sold: bottlesSold > 0 ? bottlesSold : (ref.bottles_sold || 0),
      earned: commEarned > 0 ? commEarned : (ref.earned || 0),
      pending_earned: pendingComm
    };
  });
  return res.json(enriched);
});

app.post('/api/salesman/referrals', async (req, res) => {
  const { referrer_id, full_name, phone, kyc_doc } = req.body;
  if (!full_name || !phone) {
    return res.status(400).json({ error: 'Full name and phone number are required' });
  }

  const generatedEmail = `${full_name.toLowerCase().replace(/[^a-z0-9]/g, '')}_${Math.floor(100+Math.random()*900)}@erp.com`;
  const newReqId = `req_${Date.now()}`;

  // 1. Create Onboarding Request in Super Admin's Approval Queue
  const newReq = {
    id: newReqId,
    name: full_name,
    email: generatedEmail,
    phone,
    role: 'salesman',
    warehouse_id: 'w1',
    parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23',
    requested_by: referrer_id || 'd4567890-ef34-56ff-78ff-9012abcdef34',
    status: 'pending',
    requires_password_setup: true,
    aadhaar_number: '',
    kyc_doc: kyc_doc || '',
    created_at: new Date().toISOString()
  };
  mockDb.userRequests.unshift(newReq);


  // 2. Track in salesman's referrals list
  const newReferral = {
    id: `sm_ref_${Date.now()}`,
    referrer_id: referrer_id || 'd4567890-ef34-56ff-78ff-9012abcdef34',
    referred_salesman_id: newReqId,
    full_name,
    phone,
    status: 'Pending Approval',
    earned: 0,
    bottles_sold: 0,
    kyc_doc: kyc_doc || '',
    kyc_status: 'Pending Review',
    created_at: new Date().toISOString()
  };
  if (!mockDb.salesmanReferrals) mockDb.salesmanReferrals = [];
  mockDb.salesmanReferrals.unshift(newReferral);

  if (isSupabaseConfigured) {
    try {
      await supabase.from('user_creation_requests').insert([{
        name: full_name,
        email: generatedEmail,
        role: 'salesman',
        warehouse_id: 'w1',
        parent_id: 'c3456789-de23-45ff-67ff-8901abcdef23',
        requested_by: referrer_id || null,
        status: 'pending'
      }]);
    } catch (e) {
      console.warn('user_creation_requests Supabase sync notice:', e.message);
    }
  }

  await logAudit(referrer_id || 'd4567890-ef34-56ff-78ff-9012abcdef34', 'Salesman', 'SUBMIT_REFERRAL', 'user_creation_requests', newReqId, `Submitted referral request for ${full_name} (${phone}) awaiting Super Admin approval`);
  return res.status(201).json(newReferral);
});

// 4. Daily Settlements (List, Create, Approve for Salesman & FSM)
app.get('/api/settlements', async (req, res) => {
  const { salesman_id, fsm_id, status } = req.query;

  let list = [];
  if (isSupabaseConfigured) {
    try {
      let query = supabase.from('settlements').select('*');
      if (salesman_id) query = query.eq('salesman_id', salesman_id);
      if (fsm_id) query = query.eq('fsm_id', fsm_id);
      if (status && status !== 'all') query = query.eq('status', status);
      const { data, error } = await query.order('created_at', { ascending: false });
      if (!error && data && data.length > 0) {
        list = data;
      }
    } catch (e) {
      console.warn('Supabase settlements query notice:', e.message);
    }
  }

  if (list.length === 0) {
    list = [...(mockDb.settlements || [])];
    if (salesman_id) {
      list = list.filter(s => s.salesman_id === salesman_id);
    }
    if (fsm_id) {
      list = list.filter(s => s.fsm_id === fsm_id || s.fsm_id === 'c3456789-de23-45ff-67ff-8901abcdef23' || s.fsm_id === 'u3');
    }
    if (status && status !== 'all') {
      list = list.filter(s => s.status === status);
    }
  }
  if (fsm_id) {
    list = list.filter(s => s.fsm_id === fsm_id || s.fsm_id === 'c3456789-de23-45ff-67ff-8901abcdef23' || s.fsm_id === 'u3');
  }
  if (status && status !== 'all') {
    list = list.filter(s => s.status === status);
  }

  const enriched = list.map(s => {
    const salesman = (mockDb.users || []).find(u => u.id === s.salesman_id) || { name: s.salesman_name || 'Salesman' };
    const fsm = (mockDb.users || []).find(u => u.id === s.fsm_id) || { name: s.fsm_name || 'Field Manager' };
    return { ...s, salesman, fsm };
  });

  return res.json(enriched);
});

// Single settlement by ID
app.get('/api/settlement/:id', (req, res) => {
  const { id } = req.params;
  const item = (mockDb.settlements || []).find(s => s.id === id);
  if (!item) return res.status(404).json({ error: 'Settlement not found' });
  return res.json(item);
});

const approveSettlementHandler = async (req, res) => {
  const { id } = req.params;
  const { approved_by, fsm_id } = req.body || {};

  const item = (mockDb.settlements || []).find(s => s.id === id);
  if (!item) {
    return res.status(404).json({ error: 'Settlement not found' });
  }

  item.status = 'settled';
  item.difference = 0;
  item.settled_at = new Date().toISOString();

  const returnedQty = Number(item.remaining_qty || item.unsold_bottles || 0);
  const soldQty = Number(item.bottles_sold || 0);
  const damagedQty = Number(item.damaged_qty || 0);
  const totalSettledBottles = soldQty + returnedQty + damagedQty;

  // Credit returned bottles back to FSM depot stock
  if (mockDb.fsmSettlementHub) {
    mockDb.fsmSettlementHub.depot_stock = (mockDb.fsmSettlementHub.depot_stock || 0) + returnedQty;
    mockDb.fsmSettlementHub.warehouse = mockDb.fsmSettlementHub.warehouse || {};
    mockDb.fsmSettlementHub.warehouse.sold = (mockDb.fsmSettlementHub.warehouse.sold || 0) + soldQty;
    mockDb.fsmSettlementHub.warehouse.returned = (mockDb.fsmSettlementHub.warehouse.returned || 0) + returnedQty;
    mockDb.fsmSettlementHub.warehouse.sold_value = (mockDb.fsmSettlementHub.warehouse.sold_value || 0) + Number(item.sold_amount || 0);

    // Update in team_settlement
    mockDb.fsmSettlementHub.team_settlement = mockDb.fsmSettlementHub.team_settlement || [];
    const existingIdx = mockDb.fsmSettlementHub.team_settlement.findIndex(ts => ts.settlement_id === id || ts.salesman_id === item.salesman_id);
    const teamEntry = {
      settlement_id: id,
      salesman_id: item.salesman_id,
      name: item.salesman_name || 'Salesman',
      sold: soldQty,
      unsold: returnedQty,
      remaining: returnedQty,
      damaged: damagedQty,
      damage_notes: item.damage_notes || '',
      damage_image_url: item.damage_image_url || '',
      cash_collected: item.cash_received || item.cash_collected || 0,
      online_payment: item.online_payment || 0,
      difference: 0,
      status: 'settled',
      date: 'Today',
      settled_at: item.settled_at
    };
    if (existingIdx >= 0) {
      mockDb.fsmSettlementHub.team_settlement[existingIdx] = teamEntry;
    } else {
      mockDb.fsmSettlementHub.team_settlement.unshift(teamEntry);
    }
  }

  // Deduct settled stock from Salesman's held inventory
  const smUser = (mockDb.users || []).find(u => u.id === item.salesman_id);
  if (smUser) {
    smUser.current_stock = Math.max(0, (smUser.current_stock || 0) - totalSettledBottles);
  }

  // If Supabase is connected, update DB tables
  if (isSupabaseConfigured) {
    try {
      const { data: smStock } = await supabase.from('stocks').select('*').eq('user_id', item.salesman_id).maybeSingle();
      if (smStock) {
        const updatedQty = Math.max(0, (smStock.quantity || 0) - totalSettledBottles);
        await supabase.from('stocks').update({ quantity: updatedQty }).eq('id', smStock.id);
      }
      const targetFsmId = item.fsm_id || fsm_id || 'c3456789-de23-45ff-67ff-8901abcdef23';
      const { data: fsmStock } = await supabase.from('stocks').select('*').eq('user_id', targetFsmId).maybeSingle();
      if (fsmStock) {
        await supabase.from('stocks').update({ quantity: (fsmStock.quantity || 0) + returnedQty }).eq('id', fsmStock.id);
      }
    } catch (e) {
      console.warn('Supabase settlement stock sync notice:', e.message);
    }
  }

  await logAudit(
    approved_by || fsm_id || 'u3',
    'Field Manager',
    'APPROVE_SETTLEMENT',
    'settlements',
    id,
    `Settlement approved for ${item.salesman_name || item.salesman_id}: Sold ${soldQty}, Returned ${returnedQty} btls to depot, Damaged ${damagedQty}`
  );

  return res.json(item);
};

app.put('/api/settlements/:id/approve', approveSettlementHandler);
app.put('/api/settlements/:id/accept', approveSettlementHandler);

app.get('/api/settlements/:salesman_id', (req, res) => {
  const { salesman_id } = req.params;
  const list = (mockDb.settlements || []).filter(s => s.salesman_id === salesman_id);
  const user = mockDb.users.find(u => u.id === salesman_id);
  const currentStock = user ? (Number(user.current_stock) || 0) : 0;
  const todayDispatch = {
    date_label: 'Today',
    assigned_by: 'Field Sales Manager',
    bottles_dispatched: currentStock,
    unit_price: 351,
    total_value: currentStock * 351,
    status: 'pending',
    verified: currentStock > 0
  };
  return res.json({
    today: todayDispatch,
    history: list
  });
});

app.post('/api/settlements', async (req, res) => {
  const {
    salesman_id,
    salesman_name,
    fsm_id,
    fsm_name,
    bottles_dispatched,
    bottles_sold,
    unsold_bottles,
    remaining_qty,
    damaged_qty,
    damage_notes,
    damage_image_url,
    damage_image_base64,
    unit_price,
    cash_collected,
    cash_received,
    online_payment,
    security_pin,
    status
  } = req.body;

  const dispatched = Number(bottles_dispatched) || 0;
  const sold = Number(bottles_sold) || 0;
  const remaining = Number(remaining_qty !== undefined ? remaining_qty : unsold_bottles) || 0;
  const damaged = Number(damaged_qty) || 0;
  const price = Number(unit_price) || 351;
  const cash = Number(cash_received !== undefined ? cash_received : cash_collected) || 0;
  const online = Number(online_payment) || 0;
  const totalPaid = cash + online;
  const soldAmount = sold * price;
  const unsoldValue = remaining * price;
  const totalValue = dispatched * price;
  const difference = Math.max(0, soldAmount - totalPaid);

  let finalDamageUrl = damage_image_url || '';
  if (damage_image_base64 && isSupabaseConfigured) {
    try {
      const buffer = Buffer.from(damage_image_base64, 'base64');
      const filePath = `damage_${Date.now()}_proof.png`;
      const { error: uploadError } = await supabase.storage
        .from('receipts')
        .upload(filePath, buffer, { contentType: 'image/png' });
      if (!uploadError) {
        const { data: urlData } = supabase.storage.from('receipts').getPublicUrl(filePath);
        finalDamageUrl = urlData.publicUrl;
      }
    } catch (e) {
      console.warn('Damage image upload notice:', e.message);
    }
  }

  const pin = security_pin || (Math.floor(100000 + Math.random() * 900000)).toString();

  const settlement = {
    id: `stl_${Date.now()}`,
    salesman_id: salesman_id || 'u4',
    salesman_name: salesman_name || 'Salesman John',
    fsm_id: fsm_id || 'c3456789-de23-45ff-67ff-8901abcdef23',
    fsm_name: fsm_name || 'FSM Alpha',
    date_label: 'Today',
    bottles_dispatched: dispatched,
    bottles_sold: sold,
    remaining_qty: remaining,
    unsold_bottles: remaining,
    damaged_qty: damaged,
    damage_notes: damage_notes || '',
    damage_image_url: finalDamageUrl,
    unit_price: price,
    total_value: totalValue,
    sold_amount: soldAmount,
    unsold_value: unsoldValue,
    cash_received: cash,
    cash_collected: cash,
    online_payment: online,
    total_paid: totalPaid,
    difference,
    status: status || 'pending_fsm',
    security_pin: pin,
    created_at: new Date().toISOString()
  };

  if (!mockDb.settlements) mockDb.settlements = [];
  mockDb.settlements.unshift(settlement);

  if (isSupabaseConfigured) {
    try {
      await supabase.from('settlements').insert([{
        salesman_id: salesman_id && salesman_id.length > 20 ? salesman_id : null,
        salesman_name: settlement.salesman_name,
        fsm_id: fsm_id && fsm_id.length > 20 ? fsm_id : null,
        fsm_name: settlement.fsm_name,
        date_label: 'Today',
        bottles_dispatched: dispatched,
        bottles_sold: sold,
        unsold_bottles: remaining,
        remaining_qty: remaining,
        damaged_qty: damaged,
        damage_notes: damage_notes || '',
        damage_image_url: finalDamageUrl,
        unit_price: price,
        total_value: totalValue,
        sold_amount: soldAmount,
        unsold_value: unsoldValue,
        cash_collected: cash,
        cash_received: cash,
        online_payment: online,
        total_paid: totalPaid,
        difference,
        status: status || 'pending_fsm',
        security_pin: pin
      }]);
    } catch (e) {
      console.warn('settlements Supabase insert notice:', e.message);
    }
  }

  // Also add to FSM settlement hub pending team settlements
  if (mockDb.fsmSettlementHub) {
    mockDb.fsmSettlementHub.team_settlement = mockDb.fsmSettlementHub.team_settlement || [];
    mockDb.fsmSettlementHub.team_settlement.unshift({
      settlement_id: settlement.id,
      salesman_id: settlement.salesman_id,
      name: settlement.salesman_name,
      sold: sold,
      unsold: remaining,
      remaining: remaining,
      damaged: damaged,
      damage_notes: settlement.damage_notes,
      damage_image_url: settlement.damage_image_url,
      cash_collected: cash,
      online_payment: online,
      difference,
      status: settlement.status,
      date: 'Today',
      created_at: settlement.created_at
    });
  }

  await logAudit(
    salesman_id || 'u4',
    'Salesman',
    'SUBMIT_SETTLEMENT',
    'settlements',
    settlement.id,
    `Submitted settlement: Sold ${sold}, Remaining ${remaining}, Damaged ${damaged}, Cash ₹${cash}, Online ₹${online}`
  );

  return res.status(201).json(settlement);
});

// ==========================================
// FIELD MANAGER (FSM) 5-SCREEN REDESIGN ENDPOINTS
// ==========================================

// 1. Manager Dashboard Metrics
app.get('/api/fsm/dashboard/:fsm_id', async (req, res) => {
  const fsmId = req.params.fsm_id || 'u3';
  let hub = mockDb.fsmSettlementHub || { depot_stock: 0, warehouse: { received: 0, allocated: 0, sold: 0, returned: 0 } };

  if (isSupabaseConfigured) {
    try {
      const { data: stocks } = await supabase.from('stocks').select('quantity').eq('owner_id', fsmId);
      const totalStock = (stocks || []).reduce((sum, s) => sum + (Number(s.quantity) || 0), 0);
      const { data: completedTrs } = await supabase.from('stock_transfers').select('quantity').eq('to_id', fsmId).eq('status', 'completed');
      const totalReceived = (completedTrs || []).reduce((sum, t) => sum + (Number(t.quantity) || 0), 0);

      hub = {
        depot_stock: totalStock,
        warehouse: {
          received: totalReceived,
          allocated: 0,
          sold: 0,
          returned: 0
        }
      };
    } catch (_) {}
  }
  const supervised = (mockDb.users || []).filter(u => u.parent_id === fsmId && u.role === 'salesman');
  const totalBottlesSold = supervised.reduce((sum, s) => sum + (Number(s.sold_today) || 0), 0);
  const totalAllocated = supervised.reduce((sum, s) => sum + (Number(s.current_stock) || 0), 0);
  const ratePerBottle = 10;
  const todayEarned = totalBottlesSold * ratePerBottle;

  // Compute top performers dynamically from supervised team
  const sortedSalesmen = [...supervised].sort((a, b) => (b.sold_today || 0) - (a.sold_today || 0));
  const topPerformers = sortedSalesmen.slice(0, 3).map((s, idx) => ({
    rank: idx + 1,
    name: s.name,
    bottles: s.sold_today || 0,
    has_trophy: idx === 0 && (s.sold_today || 0) > 0
  }));

  return res.json({
    earnings: {
      today_earned: todayEarned,
      bottles_sold: totalBottlesSold,
      rate_per_bottle: ratePerBottle
    },
    team_sales: {
      bottles: totalBottlesSold
    },
    stock_accountability: {
      received: hub.warehouse?.received || (hub.depot_stock + totalAllocated),
      allocated: totalAllocated,
      sold: totalBottlesSold,
      remaining: hub.depot_stock || 0
    },
    top_performers: topPerformers,
    available_depot_stock: hub.depot_stock || 0
  });
});

// 2. Supervised Team Roster
app.get('/api/fsm/team/:fsm_id', async (req, res) => {
  const fsmId = req.params.fsm_id || 'u3';
  if (isSupabaseConfigured) {
    try {
      const { data: users, error } = await supabase.from('users').select('*').eq('role', 'salesman');
      if (!error && users && users.length > 0) {
        const userIds = users.map(u => u.id);
        const { data: stocks } = await supabase.from('stocks').select('*').in('owner_id', userIds);
        const stockMap = new Map();
        (stocks || []).forEach(s => {
          stockMap.set(s.owner_id, (stockMap.get(s.owner_id) || 0) + (Number(s.quantity) || 0));
        });

        const supervised = users.filter(u => u.parent_id === fsmId || !u.parent_id || u.parent_id === 'c3456789-de23-45ff-67ff-8901abcdef23' || fsmId === 'u3' || fsmId === 'c3456789-de23-45ff-67ff-8901abcdef23');
        const activeCount = supervised.filter(u => u.is_active !== false).length;
        return res.json({
          summary: {
            active: activeCount,
            offline: supervised.length - activeCount,
            total: supervised.length
          },
          salesmen: supervised.map((u, idx) => ({
            id: u.id,
            name: u.name,
            zone: u.zone || (idx % 2 === 0 ? 'Zone A' : 'Zone B'),
            code: u.code || `SP-${(idx + 1).toString().padStart(2, '0')}`,
            is_active: u.is_active !== false,
            sold_today: u.sold_today || 0,
            current_stock: stockMap.get(u.id) || u.current_stock || 0
          }))
        });
      }
    } catch (err) {
      console.warn('Supabase fetch team roster fallback:', err.message);
    }
  }

  let supervised = (mockDb.users || []).filter(u => (u.parent_id === fsmId || !u.parent_id) && u.role === 'salesman');
  if (supervised.length === 0) {
    supervised = [
      { id: 'd4567890-ef34-56ff-78ff-9012abcdef34', name: 'Salesman John', zone: 'Zone A', code: 'SP-01', is_active: true, sold_today: 7, current_stock: 10, parent_id: fsmId, role: 'salesman' },
      { id: '7481353a-adda-4cb6-889f-d5efe2dc1bd3', name: 'Rajesh Kumar', zone: 'Zone B', code: 'SP-02', is_active: true, sold_today: 4, current_stock: 5, parent_id: fsmId, role: 'salesman' },
      { id: 'u5', name: 'Amit Kumar', zone: 'Zone C', code: 'SP-03', is_active: false, sold_today: 0, current_stock: 0, parent_id: fsmId, role: 'salesman' },
    ];
  }
  const activeCount = supervised.filter(u => u.is_active !== false).length;
  return res.json({
    summary: {
      active: activeCount,
      offline: supervised.length - activeCount,
      total: supervised.length
    },
    salesmen: supervised.map(u => ({
      id: u.id,
      name: u.name,
      zone: u.zone || 'Zone A',
      code: u.code || 'SP-00',
      is_active: u.is_active !== false,
      sold_today: u.sold_today || 0,
      current_stock: u.current_stock || 0
    }))
  });
});

// 3. Batch Stock Allocation to Supervised Salesmen
app.post('/api/fsm/allocate-batch', async (req, res) => {
  const { fsm_id, allocations } = req.body;
  if (!Array.isArray(allocations) || allocations.length === 0) {
    return res.status(400).json({ error: 'Allocations array required' });
  }
  const hub = mockDb.fsmSettlementHub || { depot_stock: 0 };
  const totalAllocated = allocations.reduce((sum, a) => sum + (Number(a.quantity) || 0), 0);
  if (totalAllocated > hub.depot_stock) {
    return res.status(400).json({ error: `Insufficient depot stock: Requested ${totalAllocated}, Available ${hub.depot_stock}` });
  }

  hub.depot_stock -= totalAllocated;
  allocations.forEach(a => {
    const u = mockDb.users.find(usr => usr.id === a.salesman_id);
    if (u) {
      u.current_stock = (u.current_stock || 0) + Number(a.quantity);
    }
  });

  await logAudit(fsm_id || 'u3', 'Field Manager', 'ALLOCATE_BATCH_STOCK', 'stock', 'batch', `Allocated ${totalAllocated} units to ${allocations.length} salesmen`);
  return res.json({
    success: true,
    total_allocated: totalAllocated,
    remaining_depot_stock: hub.depot_stock
  });
});

// 4. Candidate Referral Requests
app.get('/api/fsm/referral-requests/:fsm_id', (req, res) => {
  const fsmId = req.params.fsm_id || 'u3';
  let reqs = (mockDb.referralRequests || []).filter(r => !r.fsm_id || r.fsm_id === fsmId);
  const pendingCount = reqs.filter(r => r.status === 'pending').length;
  const inReviewCount = reqs.filter(r => r.status === 'in_review').length;

  if (req.query.filter === 'high_priority') {
    reqs = reqs.filter(r => r.priority === 'high');
  } else if (req.query.filter === 'recent') {
    reqs = reqs.filter(r => r.is_new);
  }

  return res.json({
    summary: {
      pending: pendingCount,
      in_review: inReviewCount
    },
    requests: reqs
  });
});

// 5. Approve or Reject Candidate Referral Request
app.put('/api/fsm/referral-requests/:id', async (req, res) => {
  const { id } = req.params;
  const { status, fsm_id } = req.body;
  const item = (mockDb.referralRequests || []).find(r => r.id === id);
  if (!item) {
    return res.status(404).json({ error: 'Referral request not found' });
  }
  item.status = status || 'approved';
  await logAudit(fsm_id || 'u3', 'Field Manager', 'UPDATE_REFERRAL_REQUEST', 'referral_requests', id, `Referral request marked as ${item.status}`);
  return res.json(item);
});

// 6. Settlement Hub Summary
app.get('/api/fsm/settlement/:fsm_id', (req, res) => {
  const { fsm_id } = req.params;
  const hub = mockDb.fsmSettlementHub || {
    depot_stock: 0,
    warehouse: { received: 0, sold: 0, returned: 0, difference: 0, inv_value: 0, sold_value: 0, status: 'pending_return' },
    team_settlement: []
  };

  const pendingSettlements = (mockDb.settlements || []).filter(
    s => s.status === 'pending_fsm' && (!fsm_id || s.fsm_id === fsm_id || s.fsm_id === 'u3' || s.fsm_id === 'c3456789-de23-45ff-67ff-8901abcdef23')
  );

  return res.json({
    ...hub,
    pending_settlements: pendingSettlements
  });
});

// 7. Warehouse Return QR Generation
app.post('/api/fsm/warehouse-return-qr', async (req, res) => {
  const { fsm_id, quantity } = req.body || {};
  const returnQty = Number(quantity) || 500;
  const token = `WR-RET-${Math.floor(10000 + Math.random() * 90000)}`;
  const result = {
    qr_token: token,
    fsm_id: fsm_id || 'u3',
    quantity: returnQty,
    inventory_value: returnQty * 351,
    status: 'authorized',
    expires_at: new Date(Date.now() + 86400000).toISOString(),
    created_at: new Date().toISOString()
  };
  await logAudit(fsm_id || 'u3', 'Field Manager', 'GENERATE_RETURN_QR', 'settlements', token, `Generated return QR for ${returnQty} bottles`);
  return res.json(result);
});

// 8. Settlement Reminder to Pending Salesman
app.post('/api/fsm/settlement-remind/:salesman_id', async (req, res) => {
  const { salesman_id } = req.params;
  const { fsm_id } = req.body || {};
  await logAudit(fsm_id || 'u3', 'Field Manager', 'SEND_SETTLEMENT_REMINDER', 'users', salesman_id, `Settlement reminder sent to salesman ${salesman_id}`);
  return res.json({ success: true, message: `Reminder successfully sent to ${salesman_id}` });
});

app.listen(PORT, () => {
  console.log(`ERP Backend API is running on http://localhost:${PORT}`);
});
