trigger QuoteLineItem_Trigger on QuoteLineItem (after insert, after update) {
    if (Trigger.isAfter) {
        QuoteLineItem_Handler.afterInsertMethod(Trigger.new);
    }
}