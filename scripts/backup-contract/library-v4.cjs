const schema = require('../../docs/contracts/flash-backup-v4.schema.json');
module.exports = function validateV4(document, ajv, validateDocument) {
  const validate = ajv.getSchema(schema.$id) || ajv.compile(schema);
  const fail = message => ({valid:false,errors:[{path:'/v4',code:'LIBRARY',message}]});
  if (!validate(document)) return fail(ajv.errorsText(validate.errors));
  const {trash,preferences,automaticTags,...v3} = document;
  v3.version = 'flash-backup-v3';
  const result = validateDocument(v3);
  if (!result.valid) return result;
  const unique = xs => new Set(xs).size === xs.length;
  for (const [key,ids] of Object.entries(automaticTags)) {
    if (!ids.length || !unique(ids) || !ids.every(id=>document.personalLibrary.links[key]?.includes(id))) return fail('Invalid automatic tags');
  }
  if (!unique(trash.map(t=>t.id))) return fail('Duplicate archive IDs');
  for (const item of trash) {
    if (item.expiresAt !== undefined && item.expiresAt < item.deletedAt) return fail('Archive expires before deletion');
    if (!item.automaticTagIDs.every(id=>item.tags.some(t=>t.id===id))) return fail('Dangling archived automatic tags');
    const data = {logs:item.log ? [item.log] : [],emotions:item.emotion ? [item.emotion] : [],tasks:[]};
    if (item.task) {
      const {dueKind,dueDate,dueAt,timeZone,...task} = item.task;
      task.due = dueKind === 'allDay' ? {kind:'allDay',date:dueDate} : {kind:'dateTime',at:dueAt,timeZone};
      data.tasks = [task];
    }
    const key = item.log ? 'log:'+item.log.id : item.emotion ? 'emotion:'+item.emotion.id : 'task:'+item.task.id;
    const personalLibrary = {...document.personalLibrary,tags:item.tags,links:{[key]:item.tags.map(t=>t.id)},filters:[],reminders:item.reminder ? [item.reminder] : []};
    const checked = validateDocument({...v3,data,schemas:{logs:2,emotions:2,tasks:2},personalLibrary});
    if (!checked.valid) return checked;
  }
  return {valid:true,errors:[]};
};
