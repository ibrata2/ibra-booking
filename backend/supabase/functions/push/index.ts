// روسم للتجميل — دالة إرسال الإشعارات (Supabase Edge Function)
// تستقبل الأحداث من قاعدة البيانات (push.sql) وترسلها عبر Firebase Cloud Messaging
// بالصوت المميز لكل نوع إشعار.
//
// الأسرار المطلوبة (Edge Functions → Secrets):
//   FIREBASE_SERVICE_ACCOUNT  محتوى ملف JSON لحساب الخدمة من Firebase (Project settings → Service accounts)
//   PUSH_HOOK_SECRET          نفس كلمة السر المكتوبة في push_config
// SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY موجودان تلقائياً.
//
// برمجة وتطوير ابراهيم الخزرجي

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const SA = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
const HOOK_SECRET = Deno.env.get("PUSH_HOOK_SECRET") ?? "";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const CUSTOMERS_TOPIC = "rs_customers";
const CENTER = "روسم للتجميل";

let cachedToken: { value: string; exp: number } | null = null;

async function googleToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;
  const key = await importPKCS8(SA.private_key, "RS256");
  const jwt = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(SA.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await res.json();
  cachedToken = { value: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return cachedToken.value;
}

type Target = { token?: string; topic?: string };
type Note = { title: string; body: string; sound: string; image?: string | null; data: Record<string, string> };

/** يرسل إشعاراً واحداً. يعيد false إذا كان رمز الجهاز منتهياً (فنحذفه). */
async function send(target: Target, n: Note): Promise<boolean> {
  const message: Record<string, unknown> = {
    ...target,
    notification: { title: n.title, body: n.body, ...(n.image ? { image: n.image } : {}) },
    data: n.data,
    android: {
      priority: "high",
      notification: { channel_id: n.sound, sound: n.sound, ...(n.image ? { image: n.image } : {}) },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: `${n.sound}.wav`, "mutable-content": 1 } },
      ...(n.image ? { fcm_options: { image: n.image } } : {}),
    },
  };
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${SA.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await googleToken()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ message }),
  });
  if (res.ok) return true;
  const text = await res.text();
  console.log("FCM error", res.status, text);
  return !(res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT"));
}

async function sendToUser(userId: string, kind: "customer" | "staff", n: Note) {
  const { data } = await sb.from("device_tokens").select("token").eq("user_id", userId).eq("kind", kind);
  for (const row of data ?? []) {
    const ok = await send({ token: row.token }, n);
    if (!ok) await sb.from("device_tokens").delete().eq("token", row.token);
  }
}

async function sendToStaff(n: Note) {
  const { data } = await sb.from("device_tokens").select("token").eq("kind", "staff");
  for (const row of data ?? []) {
    const ok = await send({ token: row.token }, n);
    if (!ok) await sb.from("device_tokens").delete().eq("token", row.token);
  }
}

function cut(s: string, n = 140) {
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

function fmtTime(iso: string) {
  const d = new Date(iso);
  const opts: Intl.DateTimeFormatOptions = {
    timeZone: "Asia/Baghdad", weekday: "long", day: "numeric", month: "long", hour: "numeric", minute: "2-digit", hour12: true,
  };
  return new Intl.DateTimeFormat("ar-IQ", opts).format(d);
}

async function handle(table: string, op: string, r: Record<string, any>) {
  switch (table) {
    case "posts": {
      if (op !== "INSERT" || !r.notify) return;
      const isOffer = r.kind === "offer";
      await send({ topic: CUSTOMERS_TOPIC }, {
        title: r.title || (isOffer ? `عرض جديد من ${CENTER} 🎁` : `${CENTER} نشرت شي جديد ✨`),
        body: cut(r.body || "اضغط حتى تشوف المنشور"),
        sound: r.sound || (isOffer ? "rs_offer" : "rs_post"),
        image: r.image_url,
        data: { type: "post", id: String(r.id) },
      });
      return;
    }
    case "messages": {
      if (op !== "INSERT") return;
      const { data: conv } = await sb.from("conversations").select("customer_id").eq("id", r.conversation_id).single();
      if (!conv) return;
      const body = r.kind === "image" ? "📷 صورة" : r.kind === "booking" ? "📅 تم تثبيت موعدك" : cut(r.body);
      if (r.sender === "customer") {
        const { data: cu } = await sb.from("customers").select("name").eq("id", conv.customer_id).single();
        await sendToStaff({
          title: `💬 ${cu?.name || "زبون"}`,
          body,
          sound: "rs_staff_msg",
          data: { type: "chat", conversation: String(r.conversation_id) },
        });
      } else {
        await sendToUser(conv.customer_id, "customer", {
          title: r.display_name ? `${CENTER} · ${r.display_name}` : CENTER,
          body,
          sound: "rs_msg",
          data: { type: "chat" },
        });
      }
      return;
    }
    case "coupons": {
      if (op !== "INSERT") return;
      if (r.via === "near") return; // الزبون مر قريب — جهازه نبّهه محلياً
      let sound = "rs_gift";
      if (r.offer_id) {
        const { data: o } = await sb.from("offers").select("sound").eq("id", r.offer_id).single();
        sound = o?.sound || sound;
      }
      await sendToUser(r.customer_id, "customer", {
        title: "وصلتك هدية من روسم للتجميل 🎁",
        body: cut(`${r.title}${r.discount_text ? " — " + r.discount_text : ""}`),
        sound,
        data: { type: "coupon", code: String(r.code) },
      });
      return;
    }
    case "bookings": {
      const when = fmtTime(r.start_at);
      let title = "تم تثبيت موعدك ✅";
      if (op === "UPDATE") {
        if (r.status === "cancelled") title = "تم إلغاء الموعد";
        else if (r.status === "postponed") title = "تم تأجيل الموعد";
        else if (r.status === "confirmed") title = "تم تعديل موعدك";
        else return;
      }
      await sendToUser(r.customer_id, "customer", {
        title,
        body: cut(`${r.service_name ? r.service_name + " — " : ""}${when}`),
        sound: "rs_booking",
        data: { type: "booking", id: String(r.id) },
      });
      return;
    }
  }
}

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== HOOK_SECRET || !HOOK_SECRET) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const { type, table, record } = await req.json();
    await handle(table, type, record ?? {});
    return new Response("ok");
  } catch (e) {
    console.log("push failed", e);
    return new Response("error", { status: 200 });
  }
});
