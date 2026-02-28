<template>
  <div>
    <div class="page-header">
      <div>
        <h2>PDFs</h2>
        <p class="page-description">Manage study material documents</p>
      </div>
      <button @click="showForm = !showForm" :class="showForm ? '' : 'btn-primary'">
        {{ showForm ? 'Cancel' : 'Add PDF' }}
      </button>
    </div>

    <!-- Add/Edit Form -->
    <div v-if="showForm" class="card mb-6">
      <h4 class="mb-5">{{ editingId ? 'Edit PDF' : 'New PDF' }}</h4>
      <div class="form-grid-2">
        <label>
          <span>Title</span>
          <input v-model="form.title" required placeholder="e.g. Chapter 1 - Introduction" />
        </label>
        <label>
          <span>Class Level</span>
          <select v-model="form.classLevel">
            <option v-for="c in 12" :key="c" :value="c">Class {{ c }}</option>
          </select>
        </label>
        <label>
          <span>Subject</span>
          <select v-model="form.subjectId">
            <option v-for="s in subjects" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </label>
        <label>
          <span>Page Count</span>
          <input v-model.number="form.pageCount" type="number" min="0" />
        </label>
        <label class="span-full">
          <span>Description</span>
          <textarea v-model="form.description" rows="2" placeholder="Brief description of this PDF..."></textarea>
        </label>
        <label class="span-full">
          <span>Firebase Storage Path</span>
          <input v-model="form.firebasePath" placeholder="pdfs/class5/math/chapter1.pdf" />
          <small>Upload the PDF to Firebase Storage first, then paste the path here</small>
        </label>
        <label>
          <span>Thumbnail URL</span>
          <input v-model="form.thumbnailUrl" placeholder="https://..." />
        </label>
        <label>
          <span>File Size (KB)</span>
          <input v-model.number="form.fileSizeKb" type="number" min="0" />
        </label>
      </div>
      <div class="flex gap-3 mt-4">
        <button @click="savePdf" class="btn-primary">{{ editingId ? 'Update' : 'Create' }}</button>
        <button @click="resetForm">Cancel</button>
      </div>
      <p v-if="formMsg" :class="['form-msg', formMsg.ok ? 'msg-success' : 'msg-error']">{{ formMsg.text }}</p>
    </div>

    <!-- Filters -->
    <div class="filters mb-5">
      <select v-model="filterClass" @change="loadPdfs" class="filter-select">
        <option :value="0">All Classes</option>
        <option v-for="c in 12" :key="c" :value="c">Class {{ c }}</option>
      </select>
      <select v-model="filterSubject" @change="loadPdfs" class="filter-select">
        <option value="">All Subjects</option>
        <option v-for="s in subjects" :key="s.id" :value="s.id">{{ s.name }}</option>
      </select>
    </div>

    <!-- PDFs Table -->
    <div class="card">
      <div class="table-container">
        <table v-if="pdfs.length">
          <thead><tr><th>Title</th><th>Class</th><th>Subject</th><th>Pages</th><th>Size</th><th>Active</th><th>Actions</th></tr></thead>
          <tbody>
            <tr v-for="p in pdfs" :key="p.id">
              <td class="cell-title">{{ p.title }}</td>
              <td>{{ p.class_level }}</td>
              <td>{{ p.subject_name }}</td>
              <td>{{ p.page_count }}</td>
              <td class="text-mono">{{ p.file_size_kb ? (p.file_size_kb / 1024).toFixed(1) + 'MB' : '—' }}</td>
              <td>
                <span :class="['badge', p.is_active ? 'badge-success' : 'badge-danger']">
                  {{ p.is_active ? 'Active' : 'Inactive' }}
                </span>
              </td>
              <td>
                <div class="flex gap-2">
                  <button @click="editPdf(p)" class="btn-sm btn-info">Edit</button>
                  <button @click="toggleActive(p)" class="btn-sm">
                    {{ p.is_active ? 'Disable' : 'Enable' }}
                  </button>
                  <button @click="deletePdf(p.id)" class="btn-sm btn-danger">Delete</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty-state">No PDFs found</div>
      </div>

      <div v-if="pdfData?.total > pdfData?.limit" class="pagination">
        <button v-if="pdfPage > 1" @click="pdfPage--;loadPdfs()" class="btn-sm">Previous</button>
        <span class="page-info">Page {{ pdfPage }} of {{ Math.ceil(pdfData.total / pdfData.limit) }}</span>
        <button v-if="pdfData.total > pdfPage * pdfData.limit" @click="pdfPage++;loadPdfs()" class="btn-sm">Next</button>
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
      formMsg.value = { ok: true, text: 'PDF updated' };
    } else {
      await api('pdfs', { method: 'POST', body: form });
      formMsg.value = { ok: true, text: 'PDF created' };
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

<style scoped>
.form-grid-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
}

.span-full {
  grid-column: 1 / -1;
}

.form-msg {
  font-size: 0.8125rem;
  padding: 8px 12px;
  border-radius: var(--radius-md);
  margin-top: var(--space-3);
}

.msg-success {
  background: var(--color-success-subtle);
  color: var(--color-success);
}

.msg-error {
  background: var(--color-danger-subtle);
  color: var(--color-danger);
}

.filters {
  display: flex;
  gap: var(--space-4);
  flex-wrap: wrap;
}

.filter-select {
  width: auto;
  min-width: 150px;
}

.table-container {
  overflow-x: auto;
}

.cell-title {
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--color-text-primary);
  font-weight: 500;
}

.text-mono {
  font-family: var(--font-mono);
  font-size: 0.75rem;
}

@media (max-width: 768px) {
  .form-grid-2 {
    grid-template-columns: 1fr;
  }
}
</style>
