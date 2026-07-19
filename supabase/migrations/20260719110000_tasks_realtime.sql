-- تفعيل البث اللحظي (Realtime) على جدولي المهام والردود، عشان يوصل إشعار فوري (شريط يظهر ويختفي)
-- للشخص المُسند إليه العقد عند إسناد مهمة جديدة له، أو عند وصول رد جديد على مهمة يشارك فيها
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.task_messages;
