-- ============================================================
-- تنبيه بريدي تلقائي لكل المستخدمين المفعّلين عندما يتبقى يوم واحد
-- على نهاية أي عقد. يعتمد على pg_cron (جدولة يومية) + pg_net (إرسال
-- الطلب لـ Resend API) — كله يشتغل داخل قاعدة البيانات مباشرة بدون
-- الحاجة لنشر Edge Function منفصلة.
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function public.send_contract_ending_alerts()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  resend_api_key text := 're_3kUNFSJK_PHTwrjy2TGDuHtKiKuzEZWii';
  from_address text := 'onboarding@resend.dev';
  ending_html text;
  recipient record;
  contract_count int;
begin
  -- يبني قائمة HTML بالعقود التي ينتهي تشغيلها غدًا (يبقى عليها يوم واحد بالضبط)
  select
    count(*),
    coalesce(string_agg(
      format(
        '<li><b>%s</b> — %s (%s حافلة) · ينتهي: %s</li>',
        coalesce(cl.name, 'بدون عميل'),
        coalesce(h.name, 'بدون فندق'),
        c.buses,
        to_char(c.end_date, 'DD/MM/YYYY')
      ), ''
    ), '')
  into contract_count, ending_html
  from public.contracts c
  left join public.clients cl on cl.id = c.client_id
  left join public.hotels h on h.id = c.hotel_id
  where c.end_date = current_date + interval '1 day';

  if contract_count = 0 then
    return; -- ما فيه عقود تنتهي غدًا، ما نرسل شي
  end if;

  for recipient in
    select email, name from public.app_users where active = true
  loop
    perform net.http_post(
      url := 'https://api.resend.com/emails',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || resend_api_key,
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'from', from_address,
        'to', jsonb_build_array(recipient.email),
        'subject', format('⏰ تنبيه: %s عقد ينتهي غدًا', contract_count),
        'html', format(
          '<div dir="rtl" style="font-family:sans-serif;">' ||
          '<p>مرحبًا %s،</p>' ||
          '<p>فيه <b>%s</b> عقد بيوصل تاريخ نهايته غدًا:</p>' ||
          '<ul>%s</ul>' ||
          '<p>— نظام بيان الصلوات</p>' ||
          '</div>',
          coalesce(recipient.name, recipient.email),
          contract_count,
          ending_html
        )
      )
    );
  end loop;
end;
$$;

-- نمنع أي مستخدم (anon/authenticated) من استدعاء الدالة مباشرة عبر REST API —
-- تشتغل فقط من pg_cron داخليًا (لأنها تحمل مفتاح Resend السري)
revoke execute on function public.send_contract_ending_alerts() from public, anon, authenticated;

-- يشتغل يوميًا الساعة 5:00 صباحًا UTC (8:00 صباحًا بتوقيت السعودية)
select cron.schedule(
  'contract-ending-alerts',
  '0 5 * * *',
  $$select public.send_contract_ending_alerts();$$
);
