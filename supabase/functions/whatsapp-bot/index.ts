import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = "https://mfvhurvsgnzltkwvmoki.supabase.co"
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseKey)

function reply(text) {
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><Response><Message>${text}</Message></Response>`,
    { headers: { "Content-Type": "text/xml" } }
  )
}

const categories = [
  "Food & Drinks", "Clothing", "Electronics",
  "Hair & Beauty", "Transport", "Hardware", "Other"
]

serve(async (req) => {
  const form = await req.formData()
  const body = form.get("Body")?.toString().trim() || ""
  const from = form.get("From")?.toString() || ""
  const phone = from.replace("whatsapp:", "")
  const numMedia = parseInt(form.get("NumMedia")?.toString() || "0")
  const lowerBody = body.toLowerCase()
  const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID")
  const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN")

  if (["hi","hello","start","/start","hey","help"].includes(lowerBody)) {
    await supabase.from("bot_sessions").delete().eq("phone", phone)
    await supabase.from("bot_sessions").insert({ phone, step: 1, data: {} })
    return reply("Welcome! Let's build your financial identity. What is your business name?")
  }

  if (lowerBody.startsWith("sales")) {
    const parts = body.split(/\s+/)
    const amount = parseFloat(parts[1])
    if (isNaN(amount)) return reply("Please enter a valid amount. Example: SALES 3200")
    let entryDate = new Date().toISOString().split('T')[0]
    if (parts[2] === "yesterday") {
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      entryDate = yesterday.toISOString().split('T')[0]
    } else if (parts[2]) {
      entryDate = parts[2]
    }
    const { data: ownerData } = await supabase.from("owners").select("id").eq("phone", phone).single()
    const { data: business } = await supabase.from("businesses").select("id, business_name").eq("owner_id", ownerData?.id).single()
    if (!business) return reply("You need to complete onboarding first. Reply ONBOARD to start.")
    await supabase.from("revenue_entries").insert({ business_id: business.id, amount, entry_date: entryDate, source: 'whatsapp' })
    await supabase.from("activity_history").insert({ business_id: business.id, activity_type: 'sales_reported', metadata: { amount, date: entryDate } })
    await supabase.from("trust_signals").insert({ business_id: business.id, signal_type: 'sales_entry', confidence: 0.8 })
    return reply(`✅ Sales of R${amount} recorded for ${entryDate}. Keep going! Reply STATUS to see your trust level.`)
  }

  if (lowerBody.startsWith("weekly")) {
    const amount = parseFloat(body.split(/\s+/)[1])
    if (isNaN(amount)) return reply("Example: WEEKLY 18000")
    const { data: ownerData } = await supabase.from("owners").select("id").eq("phone", phone).single()
    const { data: business } = await supabase.from("businesses").select("id").eq("owner_id", ownerData?.id).single()
    if (!business) return reply("Complete onboarding first. Reply ONBOARD.")
    await supabase.from("businesses").update({ monthly_revenue: amount * 4 }).eq("id", business.id)
    await supabase.from("activity_history").insert({ business_id: business.id, activity_type: 'weekly_sales_reported', metadata: { amount } })
    await supabase.from("trust_signals").insert({ business_id: business.id, signal_type: 'weekly_revenue', confidence: 0.9 })
    return reply(`📊 Weekly sales of R${amount} saved. Your trust score is building.`)
  }

  if (lowerBody === "receipt") {
    if (numMedia === 0) return reply("Please attach a photo of the receipt after sending RECEIPT.")
    const { data: ownerData } = await supabase.from("owners").select("id").eq("phone", phone).single()
    const { data: business } = await supabase.from("businesses").select("id").eq("owner_id", ownerData?.id).single()
    if (!business) return reply("Complete onboarding first. Reply ONBOARD.")
    const receiptUrl = form.get("MediaUrl0")?.toString()
    if (!receiptUrl) return reply("Could not process image. Try again.")
    if (twilioSid && twilioToken) {
      const blob = await fetch(receiptUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
      const fileName = `${phone}_receipt_${Date.now()}.jpg`
      await supabase.storage.from("verifications").upload(`supplier/${fileName}`, blob)
      await supabase.from("supplier_records").insert({ business_id: business.id, receipt_image_path: `supplier/${fileName}`, purchase_date: new Date().toISOString().split('T')[0] })
      await supabase.from("activity_history").insert({ business_id: business.id, activity_type: 'receipt_uploaded', metadata: { file: fileName } })
      await supabase.from("trust_signals").insert({ business_id: business.id, signal_type: 'supplier_receipt', confidence: 0.7 })
      return reply("✅ Receipt saved. Your supplier activity helps build trust.")
    } else {
      await supabase.from("supplier_records").insert({ business_id: business.id, receipt_image_path: receiptUrl, purchase_date: new Date().toISOString().split('T')[0] })
      return reply("✅ Receipt logged. (Image stored via Twilio)")
    }
  }

  if (lowerBody.startsWith("expense")) {
    const parts = body.split(/\s+/)
    const amount = parseFloat(parts[1])
    if (isNaN(amount)) return reply("Example: EXPENSE 500 transport")
    const category = parts.slice(2).join(" ") || "other"
    const { data: ownerData } = await supabase.from("owners").select("id").eq("phone", phone).single()
    const { data: business } = await supabase.from("businesses").select("id").eq("owner_id", ownerData?.id).single()
    if (!business) return reply("Complete onboarding first. Reply ONBOARD.")
    await supabase.from("expense_entries").insert({ business_id: business.id, amount, category, expense_date: new Date().toISOString().split('T')[0] })
    await supabase.from("activity_history").insert({ business_id: business.id, activity_type: 'expense_recorded', metadata: { amount, category } })
    return reply(`💸 Expense of R${amount} (${category}) recorded.`)
  }

  if (lowerBody.startsWith("stock")) {
    const amount = parseFloat(body.split(/\s+/)[1])
    if (isNaN(amount)) return reply("Example: STOCK 2000")
    const { data: ownerData } = await supabase.from("owners").select("id").eq("phone", phone).single()
    const { data: business } = await supabase.from("businesses").select("id").eq("owner_id", ownerData?.id).single()
    if (!business) return reply("Complete onboarding first. Reply ONBOARD.")
    await supabase.from("expense_entries").insert({ business_id: business.id, amount, category: "stock", expense_date: new Date().toISOString().split('T')[0] })
    await supabase.from("activity_history").insert({ business_id: business.id, activity_type: 'stock_purchased', metadata: { amount } })
    return reply(`📦 Stock purchase of R${amount} logged.`)
  }

  if (lowerBody === "status") {
    const { data: owner } = await supabase.from("owners").select("id").eq("phone", phone).single()
    if (!owner) return reply("You haven't started onboarding yet. Reply ONBOARD to begin.")
    const { data: business } = await supabase.from("businesses").select("id, business_name, location, monthly_revenue, created_at").eq("owner_id", owner.id).single()
    if (!business) return reply("Onboarding incomplete. Reply ONBOARD to continue.")
    const { count: signalCount } = await supabase.from("trust_signals").select("*", { count: "exact", head: true }).eq("business_id", business.id)
    const { count: salesCount } = await supabase.from("revenue_entries").select("*", { count: "exact", head: true }).eq("business_id", business.id)
    const { count: receiptCount } = await supabase.from("supplier_records").select("*", { count: "exact", head: true }).eq("business_id", business.id)
    let trustLevel = 30
    if (salesCount >= 4) trustLevel += 20
    if (receiptCount >= 2) trustLevel += 15
    if (signalCount >= 10) trustLevel += 10
    const tier = trustLevel >= 70 ? "Good" : trustLevel >= 50 ? "Fair" : "Building"
    return reply(
      `📊 CREDO TRUST STATUS\n━━━━━━━━━━━━━━━━━━━━\n${business.business_name}\n📍 ${business.location}\n\n🔐 TRUST LEVEL: ${trustLevel}% (${tier})\n━━━━━━━━━━━━━━━━━━━━\n📈 Sales entries: ${salesCount}\n🧾 Receipts uploaded: ${receiptCount}\n🔔 Trust signals: ${signalCount}\n\n💡 Send SALES, RECEIPT, or EXPENSE to improve your score.\nReply UPDATE for a daily report flow.`
    )
  }

  let { data: session } = await supabase.from("bot_sessions").select("*").eq("phone", phone).single()
  if (!session) {
    await supabase.from("bot_sessions").insert({ phone, step: 1, data: {} })
    session = { step: 1, data: {} }
  }

  const step = session.step
  const data = session.data || {}

  if (lowerBody === "onboard") {
    await supabase.from("bot_sessions").delete().eq("phone", phone)
    await supabase.from("bot_sessions").insert({ phone, step: 1, data: {} })
    return reply("Great! Let's begin. What is your business name?")
  }

  switch (step) {
    case 1:
      if (!body) return reply("Please enter your business name.")
      data.businessName = body
      await supabase.from("bot_sessions").update({ step: 2, data }).eq("phone", phone)
      return reply("Good. What is your full name?")
    case 2:
      if (!body) return reply("Please enter your full name.")
      data.fullName = body
      await supabase.from("bot_sessions").update({ step: 3, data }).eq("phone", phone)
      return reply(`Hi ${body}! Pick a category:\n1. Food & Drinks\n2. Clothing\n3. Electronics\n4. Hair & Beauty\n5. Transport\n6. Hardware\n7. Other`)
    case 3: {
      const ci = parseInt(body) - 1
      if (isNaN(ci) || ci < 0 || ci >= categories.length) return reply("Reply with a number 1-7.")
      data.category = categories[ci]
      await supabase.from("bot_sessions").update({ step: 4, data }).eq("phone", phone)
      return reply(`Category: ${data.category}. Where do you trade?`)
    }
    case 4:
      if (!body) return reply("Please enter your location.")
      data.location = body
      await supabase.from("bot_sessions").update({ step: 5, data }).eq("phone", phone)
      return reply("How many years have you been operating?")
    case 5: {
      const yrs = parseInt(body)
      if (isNaN(yrs)) return reply("Just the number please.")
      data.yearsOperating = yrs
      await supabase.from("bot_sessions").update({ step: 6, data }).eq("phone", phone)
      return reply("📸 Upload a photo of your ID or passport.")
    }
    case 6: {
      if (numMedia === 0) return reply("Please send a photo of your ID.")
      const idUrl = form.get("MediaUrl0")?.toString()
      if (!idUrl) return reply("Could not process image. Try again.")
      if (twilioSid && twilioToken) {
        const blob = await fetch(idUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
        await supabase.storage.from("verifications").upload(`identity/${phone}_id_${Date.now()}.jpg`, blob)
      }
      data.idPath = `identity/${phone}_id_${Date.now()}.jpg`
      await supabase.from("bot_sessions").update({ step: 7, data }).eq("phone", phone)
      return reply("✅ ID received. Now take a selfie holding your ID.")
    }
    case 7: {
      if (numMedia === 0) return reply("Send a selfie with your ID.")
      const selfieUrl = form.get("MediaUrl0")?.toString()
      if (!selfieUrl) return reply("Could not process image.")
      if (twilioSid && twilioToken) {
        const sblob = await fetch(selfieUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
        await supabase.storage.from("verifications").upload(`identity/${phone}_selfie_${Date.now()}.jpg`, sblob)
      }
      data.selfiePath = `identity/${phone}_selfie_${Date.now()}.jpg`
      await supabase.from("bot_sessions").update({ step: 8, data }).eq("phone", phone)
      return reply("👍 Selfie saved. Now a photo of your stall or shop.")
    }
    case 8: {
      if (numMedia === 0) return reply("Send a photo of your stall.")
      const stallUrl = form.get("MediaUrl0")?.toString()
      if (!stallUrl) return reply("Could not process image.")
      if (twilioSid && twilioToken) {
        const stblob = await fetch(stallUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
        await supabase.storage.from("verifications").upload(`business/${phone}_stall_${Date.now()}.jpg`, stblob)
      }
      data.stallPath = `business/${phone}_stall_${Date.now()}.jpg`
      await supabase.from("bot_sessions").update({ step: 9, data }).eq("phone", phone)
      return reply("📸 Finally, a photo of you at the stall.")
    }
    case 9: {
      if (numMedia === 0) return reply("Send a photo of you at your stall.")
      const vendorUrl = form.get("MediaUrl0")?.toString()
      if (!vendorUrl) return reply("Could not process image.")
      if (twilioSid && twilioToken) {
        const vblob = await fetch(vendorUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
        await supabase.storage.from("verifications").upload(`business/${phone}_vendor_${Date.now()}.jpg`, vblob)
      }
      data.vendorPath = `business/${phone}_vendor_${Date.now()}.jpg`
      await supabase.from("bot_sessions").update({ step: 10, data }).eq("phone", phone)
      return reply("Almost there! If you have receipts, send them now (one or more). Otherwise, reply SKIP.")
    }
    case 10: {
      if (lowerBody === "skip" || numMedia === 0) {
        const { data: newOwner } = await supabase.from("owners").insert({ phone, full_name: data.fullName }).select("id").single()
        const { data: newBiz } = await supabase.from("businesses").insert({
          business_name: data.businessName, business_type: data.category, location: data.location,
          monthly_revenue: 0, age_years: data.yearsOperating, employee_count: 1, has_bank_account: false, owner_id: newOwner.id
        }).select("id").single()
        await supabase.from("activity_history").insert({ business_id: newBiz.id, activity_type: 'onboarding_completed', metadata: { phone } })
        await supabase.from("bot_sessions").delete().eq("phone", phone)
        return reply("✅ Your Credo profile is live! Send SALES, RECEIPT, or EXPENSE to build your trust. Reply STATUS anytime.")
      }
      for (let i = 0; i < numMedia; i++) {
        const recUrl = form.get(`MediaUrl${i}`)?.toString()
        if (recUrl && twilioSid && twilioToken) {
          const recBlob = await fetch(recUrl, { headers: { Authorization: `Basic ${btoa(twilioSid + ":" + twilioToken)}` } }).then(r => r.blob())
          await supabase.storage.from("verifications").upload(`supplier/${phone}_receipt_${Date.now()}_${i}.jpg`, recBlob)
        }
      }
      const { data: newOwner2 } = await supabase.from("owners").insert({ phone, full_name: data.fullName }).select("id").single()
      const { data: newBiz2 } = await supabase.from("businesses").insert({
        business_name: data.businessName, business_type: data.category, location: data.location,
        monthly_revenue: 0, age_years: data.yearsOperating, employee_count: 1, has_bank_account: false, owner_id: newOwner2.id
      }).select("id").single()
      await supabase.from("activity_history").insert({ business_id: newBiz2.id, activity_type: 'onboarding_completed', metadata: { phone } })
      await supabase.from("bot_sessions").delete().eq("phone", phone)
      return reply("✅ Onboarding complete with receipts! Your trust profile is now building. Reply STATUS.")
    }
    default:
      return reply("I didn't understand. Reply HELP for options.")
  }
})
