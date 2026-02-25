<template>
  <div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem">
      <h2>📚 PDFs</h2>
      <button @click="showForm = !showForm" style="background:#059669">{{ showForm ? '✕ Cancel' : '+ Add PDF' }}</button>
    </div>

    <!-- Add/Edit Form -->
    <div v-if="showForm" style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;margin-bottom:1.5rem">
      <h4 style="margin-bottom:1rem">{{ editingId ? 'Edit PDF' : 'Add PDF' }}</h4>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem">
        <label>Title <input v-model="form.title" required /></label>
        <label>Class Level
          <select v-model="form.classLevel">
            <option v-for="c in 12" :key="c" :value="c">Class {{ c }}</option>
          </select>
        </label>
        <label>Subject
          <select v-model="form.subjectId">
            <option v-for="s in subjects" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </label>
        <label>Page Count <input v-model.number="form.pageCount" type="number" min="0" /></label>
        <label style="grid-column:1/-1">Description <textarea v-model="form.description" rows="2"></textarea></label>
        <label style="grid-column:1/-1">Firebase Storage Path
          <input v-model="form.firebasePath" placeholder="pdfs/class5/math/chapter1.pdf" />
          <small style="color:#6b7280">Upload the PDF to Firebase Storage first, then paste the path here</small>
        </label>
        <label>Thumbnail URL <input v-model="form.thumbnailUrl" placeholder="https://..." /></label>
        <label>File Size (KB) <input v-model.number="form.fileSizeKb" type="number" min="0" /></label>
      </div>
      <div style="display:flex;gap:0.75rem;margin-top:1rem">
        <button @click="savePdf" style="background:#059669">{{ editingId ? 'Update' : 'Create' }}</button>
        <button @click="resetForm" style="background:#333">Cancel</button>
      </div>
      <p v-if="formMsg" :style="{color: formMsg.ok ? '#10b981' : '#f87171', marginTop:'0.5rem', fontSize:'0.85rem'}">{{ formMsg.text }}</p>
    </div>

    <!-- Filters -->
    <div style="display:flex;gap:1rem;margin-bottom:1rem;flex-wrap:wrap">
      <select v-model="filterClass" @change="loadPdfs" style="width:auto">
        <option :value="0">All Classes</option>
        <option v-for="c in 12" :key="c" :value="c">Class {{ c }}</option>
      </select>
      <select v-model="filterSubject" @change="loadPdfs" style="width:auto">
        <option value="">All Subjects</option>
        <option v-for="s in subjects" :key="s.id" :value="s.id">{{ s.name }}</option>
      </select>
    </div>

    <!-- PDFs Table -->
    <div style="background:#111;border-radius:12px;padding:1.25rem;border:1px solid #222;overflow-x:auto">
      <table v-if="pdfs.length" style="font-size:0.85rem">
        <thead><tr><th>Title</th><th>Class</th><th>Subject</th><th>Pages</th><th>Size</th><th>Active</th><th>Actions</th></tr></thead>
        <tbody>
          <tr v-for="p in pdfs" :key="p.id">
            <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis">{{ p.title }}</td>
            <td>{{ p.class_level }}</td>
            <td>{{ p.subject_name }}</td>
            <td>{{ p.page_count }}</td>
            <td>{{ p.file_size_kb ? (p.file_size_kb / 1024).toFixed(1) + 'MB' : '—' }}</td>
            <td><span :style="{color: p.is_active ? '#10b981' : '#f87171'}">{{ p.is_active ? '✅' : '❌' }}</span></td>
            <td style="display:flex;gap:0.25rem">
              <button @click="editPdf(p)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#2563eb">✏️</button>
              <button @click="toggleActive(p)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#6b7280">
                {{ p.is_active ? '🔒' : '🔓' }}
              </button>
              <button @click="deletePdf(p.id)" style="font-size:0.75rem;padding:0.25rem 0.5rem;background:#dc2626">🗑️</button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else style="color:#6b7280">No PDFs found</p>

      <div v-if="pdfData?.total > pdfData?.limit" style="display:flex;gap:0.5rem;margin-top:1rem;justify-content:center">
        <button v-if="pdfPage > 1" @click="pdfPage--;loadPdfs()" style="padding:0.25rem 0.75rem;background:#333">← Prev</button>
        <span style="padding:0.5rem;color:#9ca3af;font-size:0.85rem">Page {{ pdfPage }} of {{ Math.ceil(pdfData.total / pdfData.limit) }}</span>
        <button v-if="pdfData.total > pdfPage * pdfData.limit" @click="pdfPage++;loadPdfs()" style="padding:0.25rem 0.75rem;background:#333">Next →</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { api } = useApi();
const pdfs = ref<any[]>([]);
const pdfData = ref<any>(null);
const subjects = ref<any[]>([]);
const showForm = ref(false);
const editingId = ref<string | null>(null);
const formMsg = ref<any>(null);
const filterClass = ref(0);
const filterSubject = ref('');
const pdfPage = ref(1);

const form = reactive({
  title: '', description: '', classLevel: 1, subjectId: '', firebasePath: '',
  thumbnailUrl: '', pageCount: 0, fileSizeKb: 0,
});

function resetForm() {
  Object.assign(form, { title: '', description: '', classLevel: 1, subjectId: '', firebasePath: '', thumbnailUrl: '', pageCount: 0, fileSizeKb: 0 });
  editingId.value = null;
  showForm.value = false;
  formMsg.value = null;
}

function editPdf(p: any) {
  editingId.value = p.id;
  Object.assign(form, {
    title: p.title, description: p.description || '', classLevel: p.class_level,
    subjectId: p.subject_id, firebasePath: p.firebase_path, thumbnailUrl: p.thumbnail_url || '',
    pageCount: p.page_count || 0, fileSizeKb: p.file_size_kb || 0,
  });
  showForm.value = true;
}

async function savePdf() {
  if (!form.title || !form.subjectId || !form.firebasePath) {
    formMsg.value = { ok: false, text: 'Title, subject, and Firebase path are required' };
    return;
  }
  try {
    if (editingId.value) {
      await api(`pdfs/${editingId.value}`, { method: 'PUT', body: form });
      formMsg.value = { ok: true, text: '✅ PDF updated' };
    } else {
      await api('pdfs', { method: 'POST', body: form });
      formMsg.value = { ok: true, text: '✅ PDF created' };
    }
    loadPdfs();
    setTimeout(resetForm, 1000);
  } catch (e: any) {
    formMsg.value = { ok: false, text: e.data?.message || 'Failed' };
  }
}

async function toggleActive(p: any) {
  await api(`pdfs/${p.id}`, { method: 'PUT', body: { isActive: p.is_active ? 0 : 1 } });
  loadPdfs();
}

async function deletePdf(id: string) {
  if (!confirm('Delete this PDF permanently?')) return;
  await api(`pdfs/${id}`, { method: 'DELETE' });
  loadPdfs();
}

async function loadPdfs() {
  try {
    pdfData.value = await api(`pdfs?page=${pdfPage.value}`);
    pdfs.value = pdfData.value.pdfs;
  } catch {}
}

async function loadSubjects() {
  try { subjects.value = (await api('subjects')).subjects; } catch {}
}

onMounted(() => { loadPdfs(); loadSubjects(); });
</script>
